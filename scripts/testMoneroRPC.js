#!/usr/bin/env node

/**
 * Test zkFetch with Monero RPC nodes
 * 
 * Monero nodes use JSON-RPC 2.0 protocol
 */

const { ReclaimClient } = require('@reclaimprotocol/zk-fetch');
const { verifyProof, transformForOnchain } = require('@reclaimprotocol/js-sdk');
require('dotenv').config();

const RECLAIM_APP_ID = process.env.RECLAIM_APP_ID;
const RECLAIM_APP_SECRET = process.env.RECLAIM_APP_SECRET;

// Monero RPC nodes from monero.fail
const MONERO_RPC_NODES = [
  'https://node.xmr.surf',
  'https://xmr.0xrpc.io',
  'https://xmr-node.cakewallet.com:18081',
  'https://kuk.fan',
  'https://monero.definitelynotafed.com'
];

async function testMoneroRPC(nodeUrl) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Testing: ${nodeUrl}`);
  console.log('='.repeat(60));

  try {
    const client = new ReclaimClient(RECLAIM_APP_ID, RECLAIM_APP_SECRET);
    
    console.log('📡 Generating zkTLS proof for Monero RPC call...');
    console.log('   Method: get_info (fetches node information)');
    
    // Monero RPC uses JSON-RPC 2.0
    const rpcRequest = {
      jsonrpc: '2.0',
      id: '0',
      method: 'get_info'
    };
    
    const proof = await client.zkFetch(nodeUrl + '/json_rpc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(rpcRequest)
    });

    console.log('✅ Proof generated successfully!');
    
    // Verify proof off-chain
    console.log('🔐 Verifying proof off-chain...');
    const { isVerified } = await verifyProof(proof, { 
      dangerouslyDisableContentValidation: true 
    });
    
    if (!isVerified) {
      console.log('❌ Proof verification FAILED!');
      return { success: false, error: 'Verification failed' };
    }
    
    console.log('✅ Proof verified successfully!');
    
    // Transform for on-chain
    const { claimInfo, signedClaim } = transformForOnchain(proof);
    console.log('📦 Proof details:');
    console.log('   Provider:', claimInfo.provider);
    console.log('   Identifier:', signedClaim.claim.identifier);
    console.log('   Timestamp:', signedClaim.claim.timestampS);
    
    // Try to extract some info from the context
    if (claimInfo.context) {
      try {
        const contextObj = JSON.parse(claimInfo.context);
        console.log('   Context:', contextObj);
      } catch (e) {
        console.log('   Context (raw):', claimInfo.context.substring(0, 100) + '...');
      }
    }
    
    return { success: true, nodeUrl, identifier: signedClaim.claim.identifier };
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('   Response status:', error.response.status);
    }
    return { success: false, error: error.message };
  }
}

async function runTests() {
  console.log('🚀 Testing zkFetch with Monero RPC Nodes\n');
  console.log('📍 Using JSON-RPC 2.0 protocol');
  console.log('📍 Method: get_info (returns block height, network info, etc.)');
  console.log('📍 Reclaim App ID:', RECLAIM_APP_ID);
  
  const results = [];
  
  for (const nodeUrl of MONERO_RPC_NODES) {
    const result = await testMoneroRPC(nodeUrl);
    results.push({ nodeUrl, ...result });
    
    // Wait between requests
    await new Promise(resolve => setTimeout(resolve, 3000));
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('📊 Test Results Summary');
  console.log('='.repeat(60));
  
  results.forEach(({ nodeUrl, success, error }) => {
    if (success) {
      console.log(`✅ ${nodeUrl}`);
    } else {
      console.log(`❌ ${nodeUrl}`);
      console.log(`   Error: ${error}`);
    }
  });
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\n${successCount}/${results.length} nodes succeeded`);
  
  if (successCount > 0) {
    console.log('\n🎉 zkFetch works with Monero RPC nodes!');
    console.log('\nWhat this enables:');
    console.log('  ✅ Verify Monero block height trustlessly');
    console.log('  ✅ Prove network difficulty and hash rate');
    console.log('  ✅ Verify node synchronization status');
    console.log('  ✅ Create escrows based on Monero network state');
    console.log('\nNext steps:');
    console.log('  1. Test get_block RPC method to verify specific blocks');
    console.log('  2. Test get_transactions to verify Monero payments');
    console.log('  3. Create MoneroPaymentResolver contract');
  } else {
    console.log('\n⚠️  No nodes succeeded. Possible reasons:');
    console.log('  - Nodes may not support CORS for browser requests');
    console.log('  - Nodes may require specific headers or authentication');
    console.log('  - RPC endpoint path may be different');
  }
}

runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
