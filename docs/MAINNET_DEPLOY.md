# Mainnet Deployment Guide

This document describes the procedure for deploying ReineiraOS canonical resolvers to Arbitrum One and transferring ownership to a multisig.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- ETH on Arbitrum One for gas
- Arbiscan API key for verification
- Gnosis Safe (or equivalent) multisig set up
- Protocol contract addresses (ConfidentialEscrow, etc.)

## Environment Setup

Create or update `.env`:

```bash
# Deployer key — must be funded with ETH on Arbitrum One
PRIVATE_KEY=0x...

# RPC endpoint
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc

# Arbiscan API key for contract verification
ETHERSCAN_API_KEY=...

# Protocol contract that will call onConditionSet (e.g., ConfidentialEscrow)
PROTOCOL_ADDRESS=0x...

# Compliance/regulatory operations address
COMPLIANCE_ADDRESS=0x...

# Gnosis Safe / multisig — final owner of DEFAULT_ADMIN_ROLE
MULTISIG_ADDRESS=0x...
```

## Role Overview

Each resolver uses four roles defined in `ReineiraAccessControl`:

| Role | Purpose | Typical Holder |
|------|---------|---------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke any role; contract configuration | Multisig |
| `PROTOCOL_ROLE` | Call `onConditionSet` / `onPolicySet` | ConfidentialEscrow |
| `COMPLIANCE_ROLE` | Pause/unpause in emergencies | Compliance team wallet |
| `UPGRADE_ROLE` | UUPS proxy upgrades (if applicable) | Multisig or ops wallet |

## Deploy All Resolvers

Run the unified mainnet deployment script:

```bash
source .env
forge script script/DeployMainnet.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

This deploys:
1. `TimeLockResolver`
2. `ChainlinkPriceFeedResolver`
3. `ChainlinkFunctionsResolver`
4. `ReclaimResolver`

And automatically:
- Grants `PROTOCOL_ROLE` to `PROTOCOL_ADDRESS`
- Grants `COMPLIANCE_ROLE` to `COMPLIANCE_ADDRESS`
- Grants `DEFAULT_ADMIN_ROLE` to `MULTISIG_ADDRESS`
- **Renounces deployer's `DEFAULT_ADMIN_ROLE`**

## Deploy Individual Resolvers

If you prefer granular deployment:

```bash
# TimeLockResolver
forge script script/DeployTimeLockResolver.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify

# ChainlinkPriceFeedResolver
forge script script/DeployChainlinkPriceFeedResolver.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify

# ChainlinkFunctionsResolver
forge script script/DeployChainlinkFunctionsResolver.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify

# ReclaimResolver
forge script script/DeployReclaimResolver.s.sol \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify
```

## Post-Deployment Checklist

### 1. Verify on Arbiscan

If `--verify` failed, run manually:

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME> \
  --chain arbitrum \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Confirm Role Assignments

Check that roles are correctly assigned using `cast`:

```bash
# Check DEFAULT_ADMIN_ROLE holder
 cast call <RESOLVER_ADDRESS> \
  "hasRole(bytes32,address)(bool)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $MULTISIG_ADDRESS \
  --rpc-url $ARBITRUM_RPC_URL

# Check PROTOCOL_ROLE holder
PROTOCOL_ROLE=$(cast keccak "PROTOCOL_ROLE")
cast call <RESOLVER_ADDRESS> \
  "hasRole(bytes32,address)(bool)" \
  $PROTOCOL_ROLE \
  $PROTOCOL_ADDRESS \
  --rpc-url $ARBITRUM_RPC_URL

# Check COMPLIANCE_ROLE holder
COMPLIANCE_ROLE=$(cast keccak "COMPLIANCE_ROLE")
cast call <RESOLVER_ADDRESS> \
  "hasRole(bytes32,address)(bool)" \
  $COMPLIANCE_ROLE \
  $COMPLIANCE_ADDRESS \
  --rpc-url $ARBITRUM_RPC_URL
```

### 3. Test Pause Functionality

As the compliance owner, test emergency pause:

```bash
# Pause
 cast send <RESOLVER_ADDRESS> \
  "pause()" \
  --private-key $COMPLIANCE_PRIVATE_KEY \
  --rpc-url $ARBITRUM_RPC_URL

# Unpause
 cast send <RESOLVER_ADDRESS> \
  "unpause()" \
  --private-key $COMPLIANCE_PRIVATE_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```

### 4. Save Deployment Records

Deployment artifacts are automatically written to `deployments/arbitrum.json` if `--ffi` is enabled. If not, manually record:

```json
{
  "network": "arbitrum",
  "chainId": 42161,
  "deployedAt": "...",
  "contracts": {
    "TimeLockResolver": "0x...",
    "ChainlinkPriceFeedResolver": "0x...",
    "ChainlinkFunctionsResolver": "0x...",
    "ReclaimResolver": "0x..."
  },
  "roles": {
    "admin": "0x...",
    "protocol": "0x...",
    "compliance": "0x..."
  }
}
```

## Ownership Transfer to Multisig

The `DeployMainnet` script automatically performs ownership transfer. If deploying manually, follow these steps:

### Step 1: Grant Multisig Admin Role

```solidity
resolver.grantRole(bytes32(0), MULTISIG_ADDRESS);
```

### Step 2: Verify Multisig Can Administer

Submit a test transaction from the multisig to grant a dummy address `PROTOCOL_ROLE`.

### Step 3: Renounce Deployer Admin Role

```solidity
resolver.renounceRole(bytes32(0), DEPLOYER_ADDRESS);
```

**CRITICAL:** Do NOT renounce until you have confirmed the multisig can successfully execute admin functions. Once renounced, the deployer cannot recover access.

### Step 4: Confirm Deployer Has No Privileges

```bash
ADMIN_ROLE=0x0000000000000000000000000000000000000000000000000000000000000000
cast call <RESOLVER_ADDRESS> \
  "hasRole(bytes32,address)(bool)" \
  $ADMIN_ROLE \
  $DEPLOYER_ADDRESS \
  --rpc-url $ARBITRUM_RPC_URL
# Expected: false
```

## Emergency Procedures

### Pause All Resolvers

If a security incident is detected, the compliance owner can pause all resolvers:

```bash
for addr in $TIMELOCK $PRICEFEED $FUNCTIONS $RECLAIM; do
  cast send $addr "pause()" \
    --private-key $COMPLIANCE_PRIVATE_KEY \
    --rpc-url $ARBITRUM_RPC_URL
done
```

When paused:
- `onConditionSet` reverts
- `isConditionMet` reverts
- `submitProof` (ReclaimResolver) reverts
- `executeRequest` (ChainlinkFunctionsResolver) reverts

### Revoke Compromised Protocol

If the ConfidentialEscrow contract is compromised, the multisig can revoke its `PROTOCOL_ROLE`:

```solidity
resolver.revokeProtocolRole(COMPROMISED_PROTOCOL_ADDRESS);
```

### Upgrade Resolver

If a resolver is deployed as a UUPS proxy, the `UPGRADE_ROLE` holder can upgrade:

```solidity
resolver.upgradeToAndCall(NEW_IMPLEMENTATION_ADDRESS, "");
```

## Security Considerations

1. **Multisig Threshold:** Use at least 3-of-5 or higher for the admin multisig.
2. **Compliance Key:** Store the compliance key in a hardware wallet or separate multisig.
3. **Deployer Key:** Destroy or secure the deployer key after renouncing admin role.
4. **Verification:** Always verify contracts on Arbiscan immediately after deployment.
5. **Monitoring:** Set up monitoring for `Paused` / `Unpaused` events.

## Troubleshooting

### "CallerNotProtocol" on `onConditionSet`

The protocol address calling `onConditionSet` does not have `PROTOCOL_ROLE`. Grant it via:

```solidity
resolver.grantProtocolRole(PROTOCOL_ADDRESS);
```

### "CallerNotCompliance" on `pause`

The caller does not have `COMPLIANCE_ROLE`. Only the designated compliance address can pause.

### Verification Fails

Ensure `ETHERSCAN_API_KEY` is valid and the contract name matches exactly. Use:

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME> --chain arbitrum --watch
```
