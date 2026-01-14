# Basic ERC-20 Fork Test

This project demonstrates how to fork Hedera testnet using Hardhat and interact with an already deployed ERC-20 token on the forked network.

## Overview

Fork testing allows you to:

- Test against real deployed contracts without spending gas
- Impersonate any account (including contract owners) without their private key
- Safely experiment without affecting the live network
- Read real on-chain state while making local modifications

## Prerequisites

- Node.js (v18 or later)
- npm
- ECDSA account from the [Hedera Portal](https://portal.hedera.com/) with testnet HBAR

## Quick Start

### 1. Install Dependencies

```bash
npm install --legacy-peer-deps
```

> **Important:** The `--legacy-peer-deps` flag is required due to version constraints with the Hedera forking plugin.

### 2. Verify Hardhat Version

```bash
npx hardhat --version
# Should output:  2.22.19
```

### 3. Set Configuration Variables

```bash
npx hardhat vars set HEDERA_RPC_URL
# Enter:  https://testnet.hashio.io/api

npx hardhat vars set HEDERA_PRIVATE_KEY
# Enter: Your ECDSA account's HEX encoded private key
```

### 4. Compile Contracts

```bash
npm run compile
```

### 5. Deploy to Testnet (Optional)

If you want to deploy your own contract:

```bash
npm run deploy:testnet
```

Save the deployed contract address and block number, then update:

- `DEPLOYED_CONTRACT` in `test/ERC20Token.test.ts`
- `blockNumber` in `hardhat.config.ts`

### 6. Run Fork Tests

```bash
npm test
```

## Project Structure

```
basic-erc20-fork-test-hardhat/
├── contracts/
│   └── ERC20Token.sol      # ERC-20 token contract
├── scripts/
│   └── deploy.ts           # Deployment script
├── test/
│   └── ERC20Token.test.ts  # Fork tests
├── hardhat.config.ts       # Hardhat configuration
├── tsconfig.json           # TypeScript configuration
└── package.json            # Project dependencies
```

## Deployed Contract

This tutorial uses a pre-deployed ERC-20 contract on Hedera testnet:

- **Address:** `0xea606E2D68Ff9F211756b8cfd9026a7Eb76845C9`
- **HashScan:** [View on HashScan](https://hashscan.io/testnet/contract/0xea606E2D68Ff9F211756b8cfd9026a7Eb76845C9)
- **Block Number:** `29965248`

## Available Scripts

| Command                  | Description                       |
| ------------------------ | --------------------------------- |
| `npm run compile`        | Compile Solidity contracts        |
| `npm test`               | Run fork tests                    |
| `npm run deploy:testnet` | Deploy contract to Hedera testnet |

## Key Concepts

### Account Impersonation

The tests use Hardhat's impersonation feature to act as the real contract owner:

```typescript
await network.provider.request({
  method: "hardhat_impersonateAccount",
  params: [ownerAddress]
});
const impersonatedOwner = await ethers.getSigner(ownerAddress);
```

### Fixtures

Tests use `loadFixture` to ensure each test starts with a clean state:

```typescript
const fixture = await loadFixture(setupFixture);
```

### Local vs Remote State

| Action           | Local Fork          | Real Testnet |
| ---------------- | ------------------- | ------------ |
| Read balances    | ✅ Cached           | ❌ Read-only |
| Transfer tokens  | ✅                  | ❌           |
| Mint tokens      | ✅                  | ❌           |
| Deploy contracts | ✅                  | ❌           |
| Changes persist  | ❌ Reset after test | N/A          |

## Version Requirements

This project requires specific dependency versions due to compatibility with the Hedera forking plugin:

| Package                               | Version   | Reason                               |
| ------------------------------------- | --------- | ------------------------------------ |
| `hardhat`                             | `2.22.19` | Last version before breaking changes |
| `@nomicfoundation/hardhat-toolbox`    | `5.0.0`   | Compatible with Hardhat 2.22.x       |
| `@hashgraph/system-contracts-forking` | `0.1.2`   | Hedera forking plugin                |

Using Hardhat 2.28+ will cause a `No known hardfork for execution` error.

## Troubleshooting

### `No known hardfork for execution`

You're using an incompatible Hardhat version. Ensure you have `hardhat@2.22.19`:

```bash
npx hardhat --version
```

If not, reinstall dependencies:

```bash
rm -rf node_modules package-lock.json
npm install --legacy-peer-deps
```

### `EvmError:  Revert` in setUp

You're forking at a block before the contract was deployed. Update `blockNumber` in `hardhat.config.ts` to be >= the deployment block.

### `Error HH1:  You are not inside a Hardhat project`

Create `hardhat.config. ts` before running any Hardhat commands.

### Configuration Variables Not Found

Set the required variables:

```bash
npx hardhat vars set HEDERA_RPC_URL
npx hardhat vars set HEDERA_PRIVATE_KEY
npx hardhat vars list  # Verify they're set
```

## Resources

- [Hedera Forking Repository](https://github.com/hashgraph/hedera-forking)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Hedera Documentation](https://docs.hedera.com/)
- [Tutorial: Forking Hedera Network for Local Testing - Basic ERC-20](https://docs.hedera.com/hedera/tutorials/smart-contracts/how-to-fork-the-hedera-network-with-hardhat-basic-erc20)

## License

MIT
