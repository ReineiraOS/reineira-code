#!/usr/bin/env node

/**
 * Test zkFetch with Monero Node API
 * 
 * This script tests if zkFetch can generate proofs for Monero node endpoints
 * from monero.fail
 */

const { ReclaimClient } = require('@reclaimprotocol/zk-fetch');
const { verifyProof, transformForOnchain } = require('@reclaimprotocol/js-sdk');
require('dotenv').config();

const RECLAIM_APP_ID = process.env.RECLAIM_APP_ID;
const RECLAIM_APP_SECRET = process.env.RECLAIM_APP_SECRET;

// Test different Monero endpoints
const MONERO_ENDPOINTS = [
  { url: 'https://monero.fail/nodes.json', method: 'GET', description: 'Monero node list' },
  { url: 'https://xmr.support:18089/get_info', method: 'GET', description: 'Node info endpoint' },
  { url: 'https://node.xmr.surf/get_height', method: 'GET', description: 'Node height endpoint' }
];

async function testMoneroEndpoint(endpoint) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Testing: ${endpoint.description}`);
  console.log(`URL: ${endpoint.url}`);
  console.log('='.repeat(60));

  try {
    const client = new ReclaimClient(RECLAIM_APP_ID, RECLAIM_APP_SECRET);
    
    // Add timestamp to ensure unique proof
    const timestamp = Date.now();
    const testUrl = endpoint.url.includes('?') ? `${endpoint.url}&t=${timestamp}` : `${endpoint.url}?t=${timestamp}`;
    
    console.log('📡 Generating zkTLS proof...');
    
    const proof = await client.zkFetch(testUrl, {
      method: endpoint.method,
      headers: {
        'Accept': 'application/json'
      }
    });

    console.log('✅ Proof generated successfully!');
    
    // Verify proof off-chain
    console.log('🔐 Verifying proof off-chain...');
    const { isVerified } = await verifyProof(proof, { 
      dangerouslyDisableContentValidation: true 
    });
    
    if (!isVerified) {
      console.log('❌ Proof verification FAILED!');
      return false;
    }
    
    console.log('✅ Proof verified successfully!');
    
    // Transform for on-chain
    const { claimInfo, signedClaim } = transformForOnchain(proof);
    console.log('📦 Proof details:');
    console.log('   Provider:', claimInfo.provider);
    console.log('   Identifier:', signedClaim.claim.identifier);
    console.log('   Owner:', signedClaim.claim.owner);
    
    return true;
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('   Response status:', error.response.status);
      console.error('   Response data:', error.response.data);
    }
    return false;
  }
}

async function runTests() {
  console.log('🚀 Testing zkFetch with Monero Endpoints\n');
  console.log('📍 Testing multiple endpoints from monero.fail');
  console.log('📍 Reclaim App ID:', RECLAIM_APP_ID);
  
  const results = [];
  
  for (const endpoint of MONERO_ENDPOINTS) {
    const success = await testMoneroEndpoint(endpoint);
    results.push({ endpoint, success });
    
    // Wait a bit between requests
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('📊 Test Results Summary');
  console.log('='.repeat(60));
  
  results.forEach(({ endpoint, success }) => {
    console.log(`${success ? '✅' : '❌'} ${endpoint.description} - ${endpoint.url}`);
  });
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\n${successCount}/${results.length} endpoints succeeded`);
  
  if (successCount > 0) {
    console.log('\n🎉 zkFetch works with Monero endpoints!');
    console.log('Next steps:');
    console.log('  1. Deploy a Monero-specific resolver contract');
    console.log('  2. Configure escrow to verify Monero node data');
    console.log('  3. Use for trustless Monero payment verification');
  }
}

runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
