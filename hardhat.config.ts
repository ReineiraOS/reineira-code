import '@nomicfoundation/hardhat-toolbox-viem';
import '@nomicfoundation/hardhat-ethers';
import 'cofhe-hardhat-plugin';
import 'dotenv/config';

import type { HardhatUserConfig } from 'hardhat/config';

const PRIVATE_KEY = process.env.PRIVATE_KEY || '0x' + '0'.repeat(64);

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.25',
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'cancun',
    },
  },
  networks: {
    hardhat: {},
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL || 'https://sepolia-rollup.arbitrum.io/rpc',
      chainId: 421614,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      arbitrumSepolia: process.env.ETHERSCAN_API_KEY || '',
    },
  },
  mocha: {
    timeout: 120000,
  },
};

export default config;
