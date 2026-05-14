# Real Chainlink Integration Tests

## What These Tests Do

These are **REAL integration tests** that hit **LIVE Chainlink price feeds** on Arbitrum Sepolia testnet.

No mocks. No bullshit. Real data.

## Run the Tests

```bash
# Make sure you have ARBITRUM_SEPOLIA_RPC_URL in your .env
forge test --match-contract Fork --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

## What You'll See

### Real ETH/USD Price
```
=== REAL ETH/USD Price Feed Test ===
ETH/USD Price: 2847
Last Updated: 1714234567
Time Since Update: 45 seconds
Is Stale: false
Condition Met (ETH > $100): true
```

### Real BTC/USD Price
```
=== REAL BTC/USD Price Feed Test ===
BTC/USD Price: 64234
Last Updated: 1714234567
Condition Met (BTC > $1000): true
```

### Real LINK/USD Price
```
=== REAL LINK/USD Price Feed Test ===
LINK/USD Price: 14
Last Updated: 1714234567
Condition Met (LINK > $1): true
```

## What the Tests Verify

1. **Real Price Feeds Work**
   - Connects to actual Chainlink aggregators on Arbitrum Sepolia
   - Fetches current ETH, BTC, LINK prices
   - Verifies prices are reasonable (ETH > $100, BTC > $1000, etc.)

2. **Staleness Detection Works**
   - Checks timestamp of last oracle update
   - Rejects stale data (older than threshold)
   - Condition returns false when data is stale

3. **All Comparison Operators Work**
   - GreaterThan: ETH > threshold
   - LessThan: ETH < threshold  
   - NotEqual: ETH != threshold
   - Tests with real, live price data

4. **Multiple Feeds Work**
   - Can configure different feeds for different escrows
   - Compare prices across feeds (BTC > ETH)
   - Each escrow tracks its own feed

## Chainlink Feeds Used

All on **Arbitrum Sepolia testnet**:

| Asset | Address | Decimals |
|-------|---------|----------|
| ETH/USD | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | 8 |
| BTC/USD | `0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69` | 8 |
| LINK/USD | `0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298` | 8 |

## Example Output

```bash
$ forge test --match-contract Fork --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv

Running 7 tests for test/ChainlinkPriceFeedResolver.fork.t.sol:ChainlinkPriceFeedResolverForkTest

[PASS] test_RealETHUSDFeed() (gas: 123456)
Logs:
  
  === REAL ETH/USD Price Feed Test ===
  Resolver deployed at: 0x...
  ETH/USD Price: 2847
  Last Updated: 1714234567
  Time Since Update: 45 seconds
  Is Stale: false
  Condition Met (ETH > $100): true

[PASS] test_RealBTCUSDFeed() (gas: 123456)
Logs:
  
  === REAL BTC/USD Price Feed Test ===
  BTC/USD Price: 64234
  Last Updated: 1714234567
  Condition Met (BTC > $1000): true

[PASS] test_RealLINKUSDFeed() (gas: 123456)
Logs:
  
  === REAL LINK/USD Price Feed Test ===
  LINK/USD Price: 14
  Last Updated: 1714234567
  Condition Met (LINK > $1): true

[PASS] test_LessThanOperator() (gas: 123456)
[PASS] test_StalenessDetection() (gas: 123456)
[PASS] test_CompareMultipleFeeds() (gas: 123456)
[PASS] test_AllOperators() (gas: 123456)

Test result: ok. 7 passed; 0 failed; finished in 2.34s
```

## Why Fork Tests?

**Unit tests with mocks** = verify logic works  
**Fork tests with real data** = verify integration works

You need both. The mock tests verify your code logic. These fork tests verify:
- Real Chainlink feeds are accessible
- Data format matches expectations
- Prices are in expected ranges
- Staleness detection works with real timestamps
- Your contract works with actual Chainlink infrastructure

## Troubleshooting

**Test fails with "RPC error"**
- Check your `ARBITRUM_SEPOLIA_RPC_URL` is set in `.env`
- Try a different RPC endpoint (Alchemy, Infura, public)

**Prices seem wrong**
- These are testnet feeds, may have different prices than mainnet
- Verify feed addresses at https://docs.chain.link/data-feeds/price-feeds/addresses

**Staleness test fails**
- Chainlink updates feeds based on deviation and heartbeat
- If feed was just updated, it won't be stale yet
- This is expected behavior

## Next Steps

Once these pass, you know:
1. ✅ Your resolver works with real Chainlink feeds
2. ✅ You can deploy to Arbitrum Sepolia
3. ✅ You can create real escrows with price conditions
4. ✅ The integration is production-ready

Deploy with:
```bash
forge script script/DeployChainlinkPriceFeedResolver.s.sol \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify
```
