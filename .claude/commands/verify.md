Verify a deployed contract on Arbiscan: $ARGUMENTS

Steps:

1. Check if the argument includes a contract address. If not, read `deployments/arbitrumSepolia.json` and list available deployments.
2. Identify the contract name from the deployment record or the argument.
3. Run verification:

```bash
npx hardhat verify --network arbitrumSepolia <address>
```

4. If verification fails due to constructor arguments, add them:

```bash
npx hardhat verify --network arbitrumSepolia <address> <arg1> <arg2>
```

5. If verification fails due to compiler mismatch, ensure `hardhat.config.ts` solc version matches.
6. Report the Arbiscan verification URL on success: `https://sepolia.arbiscan.io/address/<address>#code`
