# Chainlink Integration Guide

This guide covers how to use Chainlink Data Feeds and Chainlink Functions with ReineiraOS escrows.

## Overview

ReineiraOS supports two types of Chainlink integrations:

1. **Chainlink Data Feeds** - Price oracles and real-world data feeds
2. **Chainlink Functions** - Custom off-chain computation and API calls

## 1. Chainlink Data Feeds

### What are Data Feeds?

Chainlink Data Feeds provide decentralized, tamper-proof price data and other real-world information on-chain. They're perfect for:

- Price-based escrow releases (e.g., release when ETH > $2000)
- Asset price verification
- Reserve balances
- Interest rates and volatility data

### Quick Start

#### Deploy the Resolver

```bash
forge script script/DeployChainlinkPriceFeedResolver.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
```

#### Configure an Escrow

```javascript
import { ethers } from 'ethers';

// Resolver configuration
const feedAddress = '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165'; // ETH/USD on Arbitrum Sepolia
const threshold = ethers.parseUnits('2000', 8); // $2000 in 8 decimals
const op = 0; // GreaterThan
const maxStaleness = 3600; // 1 hour

const configData = ethers.AbiCoder.defaultAbiCoder().encode(
  ['address', 'int256', 'uint8', 'uint256'],
  [feedAddress, threshold, op, maxStaleness]
);

// Set condition on escrow
await escrow.setCondition(resolverAddress, configData);
```

### Comparison Operators

```solidity
enum ComparisonOp {
    GreaterThan,        // 0: value > threshold
    GreaterThanOrEqual, // 1: value >= threshold
    LessThan,           // 2: value < threshold
    LessThanOrEqual,    // 3: value <= threshold
    Equal,              // 4: value == threshold
    NotEqual            // 5: value != threshold
}
```

### Available Price Feeds (Arbitrum Sepolia)

| Pair | Address | Decimals |
|------|---------|----------|
| ETH/USD | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | 8 |
| BTC/USD | `0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69` | 8 |
| LINK/USD | `0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298` | 8 |

Find more feeds: https://docs.chain.link/data-feeds/price-feeds/addresses

### Example Use Cases

#### 1. Price-Based Release

Release escrow when ETH price exceeds $2000:

```solidity
feedAddress: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165
threshold: 200000000000 // 2000 * 10^8
op: 0 // GreaterThan
maxStaleness: 3600 // 1 hour
```

#### 2. Price Drop Protection

Release escrow if BTC drops below $30,000:

```solidity
feedAddress: 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69
threshold: 3000000000000 // 30000 * 10^8
op: 2 // LessThan
maxStaleness: 1800 // 30 minutes
```

#### 3. Exact Price Match

Release when LINK reaches exactly $15:

```solidity
feedAddress: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298
threshold: 1500000000 // 15 * 10^8
op: 4 // Equal
maxStaleness: 3600
```

### Staleness Protection

The resolver automatically checks data freshness. If the oracle data is older than `maxStaleness`, the condition returns `false` even if the price threshold is met.

```javascript
// Check if data is stale
const isStale = await resolver.isStale(escrowId);

// Get latest value and timestamp
const [value, timestamp] = await resolver.getLatestValue(escrowId);
```

---

## 2. Chainlink Functions

### What are Chainlink Functions?

Chainlink Functions enable smart contracts to fetch data from any API and perform custom off-chain computation in a decentralized manner. Perfect for:

- API verification (GitHub stars, Twitter followers, etc.)
- Complex calculations
- Multi-source data aggregation
- Password-protected data access

### Quick Start

#### 1. Deploy the Resolver

```bash
forge script script/DeployChainlinkFunctionsResolver.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
```

#### 2. Create a Subscription

1. Visit https://functions.chain.link
2. Connect your wallet
3. Create a new subscription
4. Fund it with LINK tokens
5. Add the deployed resolver as a consumer

#### 3. Configure an Escrow

```javascript
import { ethers } from 'ethers';

// JavaScript source code to execute off-chain
const source = `
  const response = await Functions.makeHttpRequest({
    url: 'https://api.github.com/repos/ethereum/solidity'
  });
  const stars = response.data.stargazers_count;
  return Functions.encodeUint256(stars);
`;

// Configuration
const args = []; // Optional arguments
const encryptedSecretsUrls = '0x'; // Optional encrypted secrets
const subscriptionId = 123; // Your subscription ID
const gasLimit = 300000;
const donId = '0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000'; // Arbitrum Sepolia
const expectedResult = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [1000]); // Expect 1000+ stars

const configData = ethers.AbiCoder.defaultAbiCoder().encode(
  ['string', 'string[]', 'bytes', 'uint64', 'uint32', 'bytes32', 'bytes'],
  [source, args, encryptedSecretsUrls, subscriptionId, gasLimit, donId, expectedResult]
);

await escrow.setCondition(resolverAddress, configData);
```

#### 4. Execute the Request

```javascript
// Anyone can trigger the request
const tx = await resolver.executeRequest(escrowId);
await tx.wait();

// Wait for Chainlink DON to fulfill
// The condition will be met if the result matches expectedResult
```

### Network Configuration

#### Arbitrum Sepolia

```javascript
const ROUTER = '0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C';
const DON_ID = '0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000';
```

Find more networks: https://docs.chain.link/chainlink-functions/supported-networks

### Example Use Cases

#### 1. GitHub Stars Verification

Release escrow when a repository reaches 1000 stars:

```javascript
const source = `
  const response = await Functions.makeHttpRequest({
    url: 'https://api.github.com/repos/ethereum/solidity'
  });
  return Functions.encodeUint256(response.data.stargazers_count);
`;

const expectedResult = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [1000]);
```

#### 2. Weather Data

Release insurance payout based on temperature:

```javascript
const source = `
  const response = await Functions.makeHttpRequest({
    url: \`https://api.openweathermap.org/data/2.5/weather?q=London&appid=\${secrets.apiKey}\`
  });
  const temp = response.data.main.temp;
  return Functions.encodeUint256(Math.floor(temp));
`;

// Use encrypted secrets for API key
const expectedResult = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [280]); // 280K
```

#### 3. Multi-Source Price Aggregation

Aggregate prices from multiple exchanges:

```javascript
const source = `
  const [binance, coinbase, kraken] = await Promise.all([
    Functions.makeHttpRequest({ url: 'https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT' }),
    Functions.makeHttpRequest({ url: 'https://api.coinbase.com/v2/prices/ETH-USD/spot' }),
    Functions.makeHttpRequest({ url: 'https://api.kraken.com/0/public/Ticker?pair=ETHUSD' })
  ]);
  
  const prices = [
    parseFloat(binance.data.price),
    parseFloat(coinbase.data.data.amount),
    parseFloat(kraken.data.result.XETHZUSD.c[0])
  ];
  
  const avgPrice = prices.reduce((a, b) => a + b) / prices.length;
  return Functions.encodeUint256(Math.floor(avgPrice * 100));
`;
```

#### 4. Twitter Followers Check

```javascript
const source = `
  const response = await Functions.makeHttpRequest({
    url: \`https://api.twitter.com/2/users/by/username/\${args[0]}\`,
    headers: { 'Authorization': \`Bearer \${secrets.twitterToken}\` }
  });
  return Functions.encodeUint256(response.data.data.public_metrics.followers_count);
`;

const args = ['ethereum']; // Twitter username
```

### Using Encrypted Secrets

For APIs requiring authentication:

1. Create a secrets object:
```javascript
const secrets = {
  apiKey: 'your-api-key',
  token: 'your-token'
};
```

2. Encrypt and upload using Chainlink Functions toolkit
3. Reference in your source code with `secrets.apiKey`

See: https://docs.chain.link/chainlink-functions/tutorials/api-use-secrets

### Gas Limits

Default gas limit is 300,000. Adjust based on your computation:

- Simple API call: 100,000 - 200,000
- Multiple API calls: 200,000 - 300,000
- Complex computation: 300,000+

### Monitoring Requests

```javascript
// Get last request ID
const requestId = await resolver.getLastRequestId(escrowId);

// Get configuration
const config = await resolver.getConfig(escrowId);
console.log('Fulfilled:', config.fulfilled);
console.log('Expected:', config.expectedResult);
```

---

## SDK Integration Examples

### Using with ReineiraOS SDK

```javascript
import { ReineiraSDK } from '@reineira-os/sdk';
import { ethers } from 'ethers';

const sdk = new ReineiraSDK(provider);

// Example 1: Price Feed Condition
const priceFeedConfig = {
  feedAddress: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
  threshold: ethers.parseUnits('2000', 8),
  op: 0,
  maxStaleness: 3600
};

const escrow = await sdk.createEscrow({
  resolver: PRICE_FEED_RESOLVER_ADDRESS,
  resolverData: ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'int256', 'uint8', 'uint256'],
    [priceFeedConfig.feedAddress, priceFeedConfig.threshold, priceFeedConfig.op, priceFeedConfig.maxStaleness]
  ),
  // ... other escrow params
});

// Example 2: Chainlink Functions Condition
const functionsConfig = {
  source: 'return Functions.encodeUint256(42);',
  args: [],
  encryptedSecretsUrls: '0x',
  subscriptionId: 123,
  gasLimit: 300000,
  donId: '0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000',
  expectedResult: ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [42])
};

const functionsEscrow = await sdk.createEscrow({
  resolver: FUNCTIONS_RESOLVER_ADDRESS,
  resolverData: ethers.AbiCoder.defaultAbiCoder().encode(
    ['string', 'string[]', 'bytes', 'uint64', 'uint32', 'bytes32', 'bytes'],
    [
      functionsConfig.source,
      functionsConfig.args,
      functionsConfig.encryptedSecretsUrls,
      functionsConfig.subscriptionId,
      functionsConfig.gasLimit,
      functionsConfig.donId,
      functionsConfig.expectedResult
    ]
  ),
  // ... other escrow params
});

// Trigger Chainlink Functions request
await functionsEscrow.resolver.executeRequest(escrow.id);
```

---

## Testing

### Run Tests

```bash
# Test Price Feed Resolver
forge test --match-contract ChainlinkPriceFeedResolverTest -vvv

# Test Functions Resolver
forge test --match-contract ChainlinkFunctionsResolverTest -vvv
```

### Fork Testing with Real Feeds

```bash
# Test against real Arbitrum Sepolia feeds
forge test --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

---

## Resources

### Documentation
- [Chainlink Data Feeds](https://docs.chain.link/data-feeds)
- [Chainlink Functions](https://docs.chain.link/chainlink-functions)
- [Price Feed Addresses](https://docs.chain.link/data-feeds/price-feeds/addresses)
- [Functions Supported Networks](https://docs.chain.link/chainlink-functions/supported-networks)

### Tools
- [Functions Playground](https://functions.chain.link/playground)
- [Functions Subscription Manager](https://functions.chain.link)
- [Data Feeds Explorer](https://data.chain.link)

### Community
- [Chainlink Discord](https://discord.gg/chainlink)
- [ReineiraOS Telegram](https://t.me/ReineiraOS)

---

## Troubleshooting

### Price Feed Issues

**Q: Condition returns false even though price threshold is met**
- Check if data is stale: `await resolver.isStale(escrowId)`
- Verify feed address is correct for your network
- Ensure threshold uses correct decimals (usually 8 for price feeds)

**Q: How do I find the right feed address?**
- Visit https://docs.chain.link/data-feeds/price-feeds/addresses
- Select your network (Arbitrum Sepolia)
- Copy the proxy address (not aggregator)

### Chainlink Functions Issues

**Q: Request fails with "subscription not found"**
- Ensure subscription is created and funded with LINK
- Add resolver contract as consumer in subscription manager

**Q: Request succeeds but condition not fulfilled**
- Check if result matches expected format
- View request details: `await resolver.getConfig(escrowId)`
- Test source code in [Functions Playground](https://functions.chain.link/playground)

**Q: How much LINK do I need?**
- Typical request costs 0.1-0.5 LINK
- Fund subscription with at least 2-5 LINK for testing
- Monitor balance in subscription manager

**Q: Request times out**
- Reduce gas limit if computation is simple
- Simplify source code (fewer API calls)
- Check API endpoints are accessible

---

## Security Considerations

### Data Feeds
- Always use `maxStaleness` to prevent stale data
- Verify feed addresses from official Chainlink docs
- Consider using multiple feeds for critical applications

### Functions
- Validate all API responses in source code
- Use encrypted secrets for API keys
- Test source code thoroughly before production
- Monitor subscription balance
- Set appropriate gas limits

---

## Next Steps

1. Deploy your resolver contracts
2. Create test escrows with simple conditions
3. Monitor condition fulfillment
4. Integrate with your application
5. Join the community for support

Happy building! 🔗
