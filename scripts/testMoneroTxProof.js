#!/usr/bin/env node

/**
 * Test zkFetch proof generation for Monero transaction verification
 * 
 * This demonstrates how to replace trusted oracles in hookedMonero
 * with verifiable zkTLS proofs from Monero RPC nodes
 */

const { ReclaimClient } = require('@reclaimprotocol/zk-fetch');
const { verifyProof, transformForOnchain } = require('@reclaimprotocol/js-sdk');
require('dotenv').config();

const RECLAIM_APP_ID = process.env.RECLAIM_APP_ID;
const RECLAIM_APP_SECRET = process.env.RECLAIM_APP_SECRET;

// Use a reliable Monero RPC node
const MONERO_RPC_NODE = 'https://node.xmr.surf';

async function generateMoneroTxProof(txHashes) {
  console.log('🔐 Generating zkTLS Proof for Monero Transaction Verification\n');
  console.log('This replaces the trusted oracle in hookedMonero with cryptographic proof!\n');
  console.log('='.repeat(60));
  
  try {
    const client = new ReclaimClient(RECLAIM_APP_ID, RECLAIM_APP_SECRET);
    
    // Monero RPC get_transactions request
    const rpcRequest = {
      jsonrpc: '2.0',
      id: '0',
      method: 'get_transactions',
      params: {
        txs_hashes: txHashes,
        decode_as_json: true
      }
    };
    
    console.log('📡 Calling Monero RPC: get_transactions');
    console.log('   Node:', MONERO_RPC_NODE);
    console.log('   Transaction hashes:', txHashes);
    console.log('\n⏳ Generating zkTLS proof (this may take 30-60 seconds)...\n');
    
    const proof = await client.zkFetch(MONERO_RPC_NODE + '/json_rpc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(rpcRequest)
    });

    console.log('✅ Proof generated successfully!\n');
    
    // Verify proof off-chain
    console.log('🔐 Verifying proof cryptographically...');
    const { isVerified } = await verifyProof(proof, { 
      dangerouslyDisableContentValidation: true 
    });
    
    if (!isVerified) {
      console.log('❌ Proof verification FAILED!');
      return null;
    }
    
    console.log('✅ Proof verified successfully!\n');
    
    // Transform for on-chain submission
    const { claimInfo, signedClaim } = transformForOnchain(proof);
    
    console.log('='.repeat(60));
    console.log('📦 Proof Details for On-Chain Submission');
    console.log('='.repeat(60));
    console.log('Provider:', claimInfo.provider);
    console.log('Proof Identifier:', signedClaim.claim.identifier);
    console.log('Timestamp:', new Date(signedClaim.claim.timestampS * 1000).toISOString());
    console.log('Owner:', signedClaim.claim.owner);
    
    // Extract transaction data from context
    if (claimInfo.context) {
      console.log('\n📊 Transaction Data from Proof:');
      try {
        const contextObj = JSON.parse(claimInfo.context);
        const txData = contextObj.extractedParameters?.data;
        if (txData) {
          const txResponse = JSON.parse(txData);
          if (txResponse.result && txResponse.result.txs) {
            txResponse.result.txs.forEach((tx, idx) => {
              console.log(`\nTransaction ${idx + 1}:`);
              console.log('  Hash:', tx.tx_hash || 'N/A');
              console.log('  Block Height:', tx.block_height || 'N/A');
              console.log('  Confirmations:', tx.confirmations || 'N/A');
              console.log('  In Pool:', tx.in_pool || false);
              
              if (tx.as_json) {
                try {
                  const txJson = JSON.parse(tx.as_json);
                  console.log('  Version:', txJson.version);
                  console.log('  Unlock Time:', txJson.unlock_time);
                  console.log('  Outputs:', txJson.vout?.length || 0);
                } catch (e) {
                  // JSON parsing error
                }
              }
            });
          }
        }
      } catch (e) {
        console.log('  (Raw context available but not parsed)');
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('🎯 How This Replaces Trusted Oracle in hookedMonero');
    console.log('='.repeat(60));
    console.log('\n❌ OLD (Trusted Oracle):');
    console.log('   1. User burns wXMR');
    console.log('   2. Oracle watches Monero blockchain (TRUSTED)');
    console.log('   3. Oracle confirms XMR sent (TRUSTED)');
    console.log('   4. Burn finalized');
    console.log('\n✅ NEW (Trustless zkTLS):');
    console.log('   1. User burns wXMR');
    console.log('   2. LP sends XMR to user');
    console.log('   3. User generates zkTLS proof from Monero RPC');
    console.log('   4. MoneroTxResolver verifies proof on-chain');
    console.log('   5. Burn finalized (TRUSTLESS!)');
    
    console.log('\n💡 Benefits:');
    console.log('   ✅ No trusted oracle needed');
    console.log('   ✅ Cryptographically verifiable');
    console.log('   ✅ Decentralized (any Monero RPC node)');
    console.log('   ✅ Privacy-preserving (zkTLS)');
    console.log('   ✅ Censorship-resistant');
    
    console.log('\n📝 Next Steps:');
    console.log('   1. Deploy MoneroTxResolver contract');
    console.log('   2. Integrate with hookedMonero burn flow');
    console.log('   3. Replace Pyth oracle with zkFetch for price feeds');
    console.log('   4. Fully decentralized Monero bridge! 🎉');
    
    return {
      proof: claimInfo,
      signedClaim,
      success: true
    };
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.response) {
      console.error('   Response status:', error.response.status);
    }
    return null;
  }
}

// Example: Test with a real transaction hash
// You would replace this with actual transaction hashes from your bridge
const EXAMPLE_TX_HASHES = [
  // This is a placeholder - replace with real Monero tx hash
  'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
];

console.log('🌉 Trustless Monero Bridge - Transaction Verification\n');
console.log('Demonstrating zkTLS proof generation for Monero transactions');
console.log('This enables fully decentralized Monero ↔ Ethereum bridging!\n');

generateMoneroTxProof(EXAMPLE_TX_HASHES).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
