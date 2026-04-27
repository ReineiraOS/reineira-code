#!/bin/bash

# Test Chainlink Integration with REAL data on Arbitrum Sepolia
# This hits actual Chainlink price feeds - no mocks

echo "=================================================="
echo "  Chainlink Real Data Integration Tests"
echo "=================================================="
echo ""
echo "Testing with LIVE Chainlink feeds on Arbitrum Sepolia:"
echo "  - ETH/USD: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165"
echo "  - BTC/USD: 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69"
echo "  - LINK/USD: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298"
echo ""
echo "=================================================="
echo ""

# Check if RPC URL is set
if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
    echo "❌ Error: ARBITRUM_SEPOLIA_RPC_URL not set in .env"
    echo ""
    echo "Add to your .env file:"
    echo "ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc"
    echo ""
    exit 1
fi

echo "🔗 Using RPC: $ARBITRUM_SEPOLIA_RPC_URL"
echo ""

# Run fork tests
forge test \
    --match-contract ChainlinkPriceFeedResolverForkTest \
    --fork-url "$ARBITRUM_SEPOLIA_RPC_URL" \
    -vvv

echo ""
echo "=================================================="
echo "  Tests Complete"
echo "=================================================="
