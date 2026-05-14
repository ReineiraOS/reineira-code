/**
 * Chainlink Integration Examples for ReineiraOS
 * 
 * This script demonstrates how to use Chainlink Data Feeds and Functions
 * with ReineiraOS escrows.
 */

import { ethers } from 'ethers';
import dotenv from 'dotenv';

dotenv.config();

// Contract ABIs (simplified for examples)
const PRICE_FEED_RESOLVER_ABI = [
  'function onConditionSet(uint256 escrowId, bytes calldata data) external',
  'function isConditionMet(uint256 escrowId) external view returns (bool)',
  'function getLatestValue(uint256 escrowId) external view returns (int256 value, uint256 timestamp)',
  'function isStale(uint256 escrowId) external view returns (bool)',
  'function getThreshold(uint256 escrowId) external view returns (int256 threshold, uint8 op)'
];

const FUNCTIONS_RESOLVER_ABI = [
  'function onConditionSet(uint256 escrowId, bytes calldata data) external',
  'function executeRequest(uint256 escrowId) external returns (bytes32 requestId)',
  'function isConditionMet(uint256 escrowId) external view returns (bool)',
  'function getConfig(uint256 escrowId) external view returns (tuple(uint64 subscriptionId, uint32 gasLimit, bytes32 donId, bytes expectedResult, bool configured, bool fulfilled, bytes32 lastRequestId))',
  'function getSource(uint256 escrowId) external view returns (string)',
  'function getLastRequestId(uint256 escrowId) external view returns (bytes32)'
];

// Network configuration
const ARBITRUM_SEPOLIA = {
  rpcUrl: process.env.ARBITRUM_SEPOLIA_RPC_URL,
  chainId: 421614,
  // Chainlink Data Feeds
  feeds: {
    ETH_USD: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
    BTC_USD: '0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69',
    LINK_USD: '0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298'
  },
  // Chainlink Functions
  functionsRouter: '0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C',
  functionsDonId: '0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000'
};

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider(ARBITRUM_SEPOLIA.rpcUrl);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

/**
 * Example 1: Configure Price Feed Condition
 * Release escrow when ETH price exceeds $2000
 */
async function example1_PriceFeedCondition() {
  console.log('\n=== Example 1: Price Feed Condition ===\n');
  
  const resolverAddress = process.env.PRICE_FEED_RESOLVER_ADDRESS;
  const resolver = new ethers.Contract(resolverAddress, PRICE_FEED_RESOLVER_ABI, signer);
  
  const escrowId = 1;
  const feedAddress = ARBITRUM_SEPOLIA.feeds.ETH_USD;
  const threshold = ethers.parseUnits('2000', 8); // $2000 with 8 decimals
  const op = 0; // GreaterThan
  const maxStaleness = 3600; // 1 hour
  
  console.log('Configuration:');
  console.log('- Feed:', feedAddress);
  console.log('- Threshold: $2000');
  console.log('- Operator: GreaterThan');
  console.log('- Max Staleness: 1 hour\n');
  
  // Encode configuration data
  const configData = ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'int256', 'uint8', 'uint256'],
    [feedAddress, threshold, op, maxStaleness]
  );
  
  // Set condition (in production, this would be called by escrow contract)
  console.log('Setting condition...');
  const tx = await resolver.onConditionSet(escrowId, configData);
  await tx.wait();
  console.log('✓ Condition set!\n');
  
  // Check current state
  const [value, timestamp] = await resolver.getLatestValue(escrowId);
  const isStale = await resolver.isStale(escrowId);
  const isMet = await resolver.isConditionMet(escrowId);
  
  console.log('Current State:');
  console.log('- ETH Price:', ethers.formatUnits(value, 8));
  console.log('- Last Update:', new Date(Number(timestamp) * 1000).toISOString());
  console.log('- Is Stale:', isStale);
  console.log('- Condition Met:', isMet);
}

/**
 * Example 2: Monitor Price Feed
 * Continuously monitor price and condition status
 */
async function example2_MonitorPriceFeed() {
  console.log('\n=== Example 2: Monitor Price Feed ===\n');
  
  const resolverAddress = process.env.PRICE_FEED_RESOLVER_ADDRESS;
  const resolver = new ethers.Contract(resolverAddress, PRICE_FEED_RESOLVER_ABI, provider);
  
  const escrowId = 1;
  
  console.log('Monitoring escrow', escrowId, '...\n');
  
  // Monitor every 10 seconds
  setInterval(async () => {
    try {
      const [value, timestamp] = await resolver.getLatestValue(escrowId);
      const [threshold, op] = await resolver.getThreshold(escrowId);
      const isStale = await resolver.isStale(escrowId);
      const isMet = await resolver.isConditionMet(escrowId);
      
      const price = ethers.formatUnits(value, 8);
      const thresholdPrice = ethers.formatUnits(threshold, 8);
      
      console.log(`[${new Date().toISOString()}]`);
      console.log(`  Price: $${price} | Threshold: $${thresholdPrice} | Met: ${isMet} | Stale: ${isStale}`);
    } catch (error) {
      console.error('Error:', error.message);
    }
  }, 10000);
}

/**
 * Example 3: Chainlink Functions - GitHub Stars
 * Release escrow when repository reaches 1000 stars
 */
async function example3_ChainlinkFunctions_GitHub() {
  console.log('\n=== Example 3: Chainlink Functions - GitHub Stars ===\n');
  
  const resolverAddress = process.env.FUNCTIONS_RESOLVER_ADDRESS;
  const resolver = new ethers.Contract(resolverAddress, FUNCTIONS_RESOLVER_ABI, signer);
  
  const escrowId = 2;
  const subscriptionId = process.env.CHAINLINK_SUBSCRIPTION_ID;
  
  // JavaScript source code to execute off-chain
  const source = `
    const response = await Functions.makeHttpRequest({
      url: 'https://api.github.com/repos/ethereum/solidity'
    });
    const stars = response.data.stargazers_count;
    return Functions.encodeUint256(stars);
  `;
  
  const args = [];
  const encryptedSecretsUrls = '0x';
  const gasLimit = 300000;
  const donId = ARBITRUM_SEPOLIA.functionsDonId;
  const expectedResult = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [1000]);
  
  console.log('Configuration:');
  console.log('- Repository: ethereum/solidity');
  console.log('- Expected Stars: >= 1000');
  console.log('- Subscription ID:', subscriptionId);
  console.log('- Gas Limit:', gasLimit, '\n');
  
  // Encode configuration data
  const configData = ethers.AbiCoder.defaultAbiCoder().encode(
    ['string', 'string[]', 'bytes', 'uint64', 'uint32', 'bytes32', 'bytes'],
    [source, args, encryptedSecretsUrls, subscriptionId, gasLimit, donId, expectedResult]
  );
  
  // Set condition
  console.log('Setting condition...');
  const tx1 = await resolver.onConditionSet(escrowId, configData);
  await tx1.wait();
  console.log('✓ Condition set!\n');
  
  // Execute request
  console.log('Executing Chainlink Functions request...');
  const tx2 = await resolver.executeRequest(escrowId);
  const receipt = await tx2.wait();
  console.log('✓ Request sent!\n');
  
  // Get request ID
  const requestId = await resolver.getLastRequestId(escrowId);
  console.log('Request ID:', requestId);
  console.log('\nWaiting for Chainlink DON to fulfill request...');
  console.log('(This may take 1-2 minutes)\n');
  
  // Poll for fulfillment
  let fulfilled = false;
  while (!fulfilled) {
    await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
    
    const config = await resolver.getConfig(escrowId);
    fulfilled = config.fulfilled;
    
    if (fulfilled) {
      console.log('✓ Request fulfilled!');
      console.log('✓ Condition met:', await resolver.isConditionMet(escrowId));
    } else {
      console.log('Still waiting...');
    }
  }
}

/**
 * Example 4: Chainlink Functions - Weather Data
 * Release insurance payout based on temperature
 */
async function example4_ChainlinkFunctions_Weather() {
  console.log('\n=== Example 4: Chainlink Functions - Weather Data ===\n');
  
  const resolverAddress = process.env.FUNCTIONS_RESOLVER_ADDRESS;
  const resolver = new ethers.Contract(resolverAddress, FUNCTIONS_RESOLVER_ABI, signer);
  
  const escrowId = 3;
  const subscriptionId = process.env.CHAINLINK_SUBSCRIPTION_ID;
  
  // JavaScript source code with encrypted API key
  const source = `
    const city = args[0];
    const response = await Functions.makeHttpRequest({
      url: \`https://api.openweathermap.org/data/2.5/weather?q=\${city}&appid=\${secrets.apiKey}\`
    });
    const tempKelvin = response.data.main.temp;
    return Functions.encodeUint256(Math.floor(tempKelvin));
  `;
  
  const args = ['London'];
  const encryptedSecretsUrls = process.env.ENCRYPTED_SECRETS_URL || '0x'; // Upload secrets first
  const gasLimit = 300000;
  const donId = ARBITRUM_SEPOLIA.functionsDonId;
  const expectedResult = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [280]); // 280K (~7°C)
  
  console.log('Configuration:');
  console.log('- City: London');
  console.log('- Expected Temp: <= 280K (~7°C)');
  console.log('- Use Case: Parametric insurance payout\n');
  
  const configData = ethers.AbiCoder.defaultAbiCoder().encode(
    ['string', 'string[]', 'bytes', 'uint64', 'uint32', 'bytes32', 'bytes'],
    [source, args, encryptedSecretsUrls, subscriptionId, gasLimit, donId, expectedResult]
  );
  
  console.log('Setting condition...');
  const tx = await resolver.onConditionSet(escrowId, configData);
  await tx.wait();
  console.log('✓ Condition set!');
  console.log('\nNote: Remember to upload encrypted secrets with your API key');
  console.log('See: https://docs.chain.link/chainlink-functions/tutorials/api-use-secrets');
}

/**
 * Example 5: Multi-Source Price Aggregation
 * Aggregate prices from multiple exchanges
 */
async function example5_ChainlinkFunctions_MultiSource() {
  console.log('\n=== Example 5: Multi-Source Price Aggregation ===\n');
  
  const source = `
    // Fetch from multiple exchanges
    const [binance, coinbase, kraken] = await Promise.all([
      Functions.makeHttpRequest({ 
        url: 'https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT' 
      }),
      Functions.makeHttpRequest({ 
        url: 'https://api.coinbase.com/v2/prices/ETH-USD/spot' 
      }),
      Functions.makeHttpRequest({ 
        url: 'https://api.kraken.com/0/public/Ticker?pair=ETHUSD' 
      })
    ]);
    
    // Parse prices
    const prices = [
      parseFloat(binance.data.price),
      parseFloat(coinbase.data.data.amount),
      parseFloat(kraken.data.result.XETHZUSD.c[0])
    ];
    
    // Calculate average
    const avgPrice = prices.reduce((a, b) => a + b) / prices.length;
    
    // Return price in cents (multiply by 100)
    return Functions.encodeUint256(Math.floor(avgPrice * 100));
  `;
  
  console.log('Source Code:');
  console.log(source);
  console.log('\nThis example aggregates ETH/USD price from:');
  console.log('- Binance');
  console.log('- Coinbase');
  console.log('- Kraken');
  console.log('\nReturns average price in cents');
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  const example = args[0];
  
  console.log('Chainlink Integration Examples for ReineiraOS');
  console.log('==============================================');
  
  switch (example) {
    case '1':
      await example1_PriceFeedCondition();
      break;
    case '2':
      await example2_MonitorPriceFeed();
      break;
    case '3':
      await example3_ChainlinkFunctions_GitHub();
      break;
    case '4':
      await example4_ChainlinkFunctions_Weather();
      break;
    case '5':
      await example5_ChainlinkFunctions_MultiSource();
      break;
    default:
      console.log('\nAvailable examples:');
      console.log('  1 - Price Feed Condition (ETH > $2000)');
      console.log('  2 - Monitor Price Feed');
      console.log('  3 - Chainlink Functions - GitHub Stars');
      console.log('  4 - Chainlink Functions - Weather Data');
      console.log('  5 - Multi-Source Price Aggregation\n');
      console.log('Usage: node scripts/chainlinkExamples.js <example-number>');
      console.log('Example: node scripts/chainlinkExamples.js 1');
  }
}

main().catch(console.error);
