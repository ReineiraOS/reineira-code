Deploy a contract to Arbitrum Sepolia: $ARGUMENTS

Steps:

1. Identify which contract to deploy from the argument. If no contract specified, list all contracts in `contracts/resolvers/` and `contracts/policies/` and ask which one.
2. Verify the contract compiles: `npx hardhat compile`
3. Verify `.env` has `PRIVATE_KEY` and `ARBITRUM_SEPOLIA_RPC_URL` set.
4. Run `npx hardhat run scripts/deploy.ts --network arbitrumSepolia` — the script will deploy the specified contract.
5. The deployment record is saved to `deployments/arbitrumSepolia.json`.
6. After deployment, suggest next steps:
   - For resolvers: "Attach to an escrow with the SDK — see CLAUDE.md 'SDK integration' section"
   - For policies: "Register with PolicyRegistry at 0xf421363B642315BD3555dE2d9BD566b7f9213c8E"
7. If the user wants to verify on Arbiscan, run: `npx hardhat verify --network arbitrumSepolia <address>`
