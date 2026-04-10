# Deploy Contract

Deploy a contract to Arbitrum Sepolia: $ARGUMENTS

## Process

1. Identify which contract to deploy from the argument. If no contract specified, list all contracts in `contracts/resolvers/` and `contracts/policies/` and ask which one.
2. Verify the contract compiles: `npx hardhat compile`
3. Verify `.env` has `PRIVATE_KEY` and `ARBITRUM_SEPOLIA_RPC_URL` set.
4. Run `npx hardhat run scripts/deploy.ts --network arbitrumSepolia`
5. Deployment record is saved to `deployments/arbitrumSepolia.json`.
6. Suggest next steps:
   - For resolvers: "Attach to an escrow with the SDK"
   - For policies: "Register with PolicyRegistry"
7. Offer to verify on Arbiscan: `npx hardhat verify --network arbitrumSepolia <address>`

## Acceptance Criteria

- [ ] Contract compiles without errors
- [ ] Deployment succeeds
- [ ] Address recorded in `deployments/arbitrumSepolia.json`
- [ ] Next steps communicated

## Output

Return: deployed contract address + next steps.
