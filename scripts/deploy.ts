import hre from 'hardhat';
import fs from 'fs';
import path from 'path';

async function main() {
  const contractName = process.env.CONTRACT_NAME;

  if (!contractName) {
    // List available contracts
    const resolvers = fs.readdirSync('contracts/resolvers').filter((f) => f.endsWith('.sol'));
    const policies = fs.readdirSync('contracts/policies').filter((f) => f.endsWith('.sol'));

    console.log('\nAvailable contracts:');
    if (resolvers.length) {
      console.log('  Resolvers:', resolvers.map((f) => f.replace('.sol', '')).join(', '));
    }
    if (policies.length) {
      console.log('  Policies:', policies.map((f) => f.replace('.sol', '')).join(', '));
    }
    if (!resolvers.length && !policies.length) {
      console.log('  (none — create a contract first)');
    }

    console.log('\nUsage: CONTRACT_NAME=MyResolver npx hardhat run scripts/deploy.ts --network arbitrumSepolia\n');
    return;
  }

  console.log(`\nDeploying ${contractName} to ${hre.network.name}...`);

  const [deployer] = await hre.viem.getWalletClients();
  console.log('Deployer:', deployer.account.address);

  const contract = await hre.viem.deployContract(contractName);
  const address = contract.address;

  console.log(`${contractName} deployed to: ${address}`);

  // Save deployment record
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  const deploymentsFile = path.join(deploymentsDir, `${hre.network.name}.json`);

  let deployments: Record<string, unknown> = {};
  if (fs.existsSync(deploymentsFile)) {
    deployments = JSON.parse(fs.readFileSync(deploymentsFile, 'utf-8'));
  }

  const record = {
    ...deployments,
    [contractName]: {
      address,
      deployer: deployer.account.address,
      deployedAt: new Date().toISOString(),
      network: hre.network.name,
    },
  };

  fs.writeFileSync(deploymentsFile, JSON.stringify(record, null, 2));
  console.log(`Deployment saved to ${deploymentsFile}`);

  console.log('\nNext steps:');
  console.log(`  Verify:  npx hardhat verify --network ${hre.network.name} ${address}`);
  console.log(`  Attach:  Use the SDK to connect this contract to an escrow or insurance pool`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
