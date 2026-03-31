# Advanced HTS Fork Testing with Hardhat

This project demonstrates advanced fork testing on Hedera using the Hedera Token Service (HTS) system contract precompiles. It shows how to create, mint, and transfer HTS fungible tokens on a forked network.

## Overview

This example covers:

- Creating HTS fungible tokens using system contract precompiles
- Minting tokens with the contract as the supply key holder
- Transferring HTS tokens between accounts
- Querying token information via HTS and ERC-20 interfaces
- Fork testing against real deployed contracts

## Prerequisites

- Node.js v18 or later
- An ECDSA account from the [Hedera Portal](https://portal.hedera.com/) with testnet HBAR
- Basic understanding of Solidity and TypeScript
- Familiarity with [HTS system contract precompiles](https://github.com/hashgraph/hedera-smart-contracts/tree/main/contracts/system-contracts/hedera-token-service)

## Project Structure

```
advanced-hts-fork-test-hardhat/
├── contracts/
│   └── HTSTokenManager.sol    # HTS token management contract
├── scripts/
│   └── deploy.ts              # Deployment script (deploys contract + creates token)
├── test/
│   ├── HTSTokenManager.test.ts    # Fork tests for HTS operations (testnet)
│   ├── SaucerSwapForkTest.test.ts # Real-world mainnet fork test (SaucerSwap)
│   └── BonzoForkTest.test.ts      # Real-world mainnet fork test (Bonzo lending)
├── hardhat.config.ts              # Hardhat configuration (testnet fork)
├── hardhat.config.mainnet.ts      # Hardhat configuration (mainnet fork)
├── package. json
├── tsconfig.json
└── README.md
```

## Setup

### 1. Install Dependencies

```bash
npm install --legacy-peer-deps
```

### 2. Set Configuration Variables

```bash
npx hardhat vars set HEDERA_RPC_URL
# Enter:  https://testnet.hashio.io/api

npx hardhat vars set HEDERA_PRIVATE_KEY
# Enter: Your ECDSA account's HEX encoded private key
```

### 3. Compile Contracts

```bash
npm run compile
```

## Deployment

Deploy the contract and create an HTS token on testnet:

```bash
npm run deploy:testnet
```

Example output:

```
Deploying contracts with the account: 0xA98556A4deeB07f21f8a66093989078eF86faa30
Account balance: 119515.68709805 HBAR

--- Deploying HTSTokenManager ---
HTSTokenManager deployed to: 0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4
View on HashScan: https://hashscan.io/testnet/contract/0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4

--- Creating HTS Fungible Token ---
Creating token "TestForkToken" (TFT)...
Sending 15 HBAR for token creation...
createFungibleTokenPublic() tx hash: 0x99b3197d0e2445f3f9b310d422a8bc2ee45d7c6093093a0235e12cfaca2ae610
HTS Token created at: 0x000000000000000000000000000000000080FDF2
View token on HashScan: https://hashscan.io/testnet/token/0x000000000000000000000000000000000080FDF2

Deployed at block number: 33462232

============================================================
DEPLOYMENT SUMMARY
============================================================
HTSTokenManager Contract: 0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4
HTS Token Address:         0x000000000000000000000000000000000080FDF2
Block Number:             33462232
============================================================

=== IMPORTANT ===
Update your hardhat.config.ts with:
  blockNumber: 33462232

Update your test file with:
  DEPLOYED_CONTRACT = "0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4"
  TOKEN_ADDRESS = "0x000000000000000000000000000000000080FDF2"
```

### 4. Update Configuration

After deployment, update the following files with the values from the deployment output:

**hardhat.config.ts:**

```typescript
blockNumber: 33462232, // Your deployment block number
```

**test/HTSTokenManager.test.ts:**

```typescript
const DEPLOYED_CONTRACT = "0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4";
const TOKEN_ADDRESS = "0x000000000000000000000000000000000080FDF2";
```

## Available Scripts

| Command | Description |
| ------- | ----------- |
| `npm run compile` | Compile Solidity contracts |
| `npm test` | Run HTS fork tests (testnet) |
| `npm run test:saucerswap` | Run SaucerSwap tests (mainnet fork) |
| `npm run test:bonzo` | Run Bonzo Finance tests (mainnet fork) |
| `npm run test:mainnet` | Run all mainnet fork tests |
| `npm run deploy:testnet` | Deploy contract + create HTS token on testnet |

## Running Tests

### HTS Fork Tests (Testnet)

Run the HTS fork tests against your deployed testnet contract:

```bash
npm test
```

Example output:

```
  HTSTokenManager - HTS Forking Tests
    Token Info
Successfully retrieved token info
      ✔ should get token info for the pre-created token
Successfully retrieved fungible token info
      ✔ should get fungible token info for the pre-created token
Token Name:  TestForkToken
Token Symbol: TFT
Token Decimals: 0
Token Total Supply: 0
      ✔ should read token properties via ERC-20 interface
    Token Minting
Minted 1000 tokens.  New total supply: 1000
      ✔ should mint tokens successfully
First mint - New total supply: 500
Second mint - New total supply: 800
      ✔ should mint tokens multiple times and track total supply
Treasury balance before mint: 0
Treasury balance after mint: 2000
      ✔ should increase treasury balance after minting
    Token Transfers
Alice balance before transfer:  0
Alice balance after transfer: 1000
      ✔ should transfer tokens from treasury to alice
Transferred 2000 to alice
Transferred 3000 to bob
Alice final balance: 2000
Bob final balance: 3000
      ✔ should transfer tokens to multiple recipients
Initial total supply: 0
Minted 3000 tokens
Supply after mint: 3000
Transferred 1500 to alice
Alice balance:  1500
      ✔ should mint and then transfer in sequence
    Token Creation
Created new token at:  0x0000000000000000000000000000000000000408
      ✔ should create a new token via the contract
    Fork Network Verification
Current fork block number: 33462232
      ✔ should be connected to a forked network
Contract at 0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4 has 17144 bytes of code
      ✔ should be interacting with real deployed contract
Token at 0x000000000000000000000000000000000080FDF2 exists on the forked network
      ✔ should be able to access the pre-created token
Contract (treasury) balance: 100
      ✔ should verify contract is the token treasury

  14 passing (544ms)
```

## Contract Overview

### HTSTokenManager.sol

The contract provides the following functions:

| Function                     | Description                                                               |
| ---------------------------- | ------------------------------------------------------------------------- |
| `createFungibleTokenPublic`  | Creates a new HTS fungible token with contract as treasury and supply key |
| `mintTokenPublic`            | Mints additional tokens to the treasury                                   |
| `transferTokenPublic`        | Transfers tokens between accounts                                         |
| `getTokenInfoPublic`         | Retrieves token information                                               |
| `getFungibleTokenInfoPublic` | Retrieves fungible token specific information                             |

### Key Design Decisions

- **Contract as Treasury**: The contract itself is set as the token treasury, receiving all minted tokens
- **Contract as Supply Key**: The contract holds the supply key, allowing it to mint tokens without external authorization
- **Contract as Admin Key**: The contract holds the admin key for token management

## How It Works

### Token Creation

When `createFungibleTokenPublic` is called:

1. A new HTS fungible token is created
2. The contract is set as the treasury (receives minted tokens)
3. The contract is set as the supply key holder (can mint)
4. The contract is set as the admin key holder (can manage)

### Minting

When `mintTokenPublic` is called:

1. The contract calls the HTS precompile to mint tokens
2. Tokens are minted to the treasury (the contract itself)
3. The `MintedToken` event is emitted with the new total supply

### Transferring

When `transferTokenPublic` is called:

1. The contract calls the HTS precompile to transfer tokens
2. Tokens move from sender to receiver
3. The `ResponseCode` event confirms success

## Dependencies

| Package                               | Version | Purpose                           |
| ------------------------------------- | ------- | --------------------------------- |
| `hardhat`                             | 2.22.19 | Development framework             |
| `@hashgraph/system-contracts-forking` | 0.1.2   | Hedera forking plugin             |
| `@hashgraph/smart-contracts`          | latest  | HTS system contract interfaces    |
| `@nomicfoundation/hardhat-toolbox`    | 5.0.0   | Hardhat development tools         |
| `@openzeppelin/contracts`             | ^5.0.0  | Standard contract implementations |

## Bonus: Real-World Mainnet Fork Tests (SaucerSwap + Bonzo)

The repo includes bonus tests that fork **Hedera mainnet** and interact with production DeFi contracts.

### Running Mainnet Tests

A separate `hardhat.config.mainnet.ts` is provided for mainnet forking. Use the npm scripts:

```bash
npm run test:saucerswap    # SaucerSwap tests only
npm run test:bonzo         # Bonzo Finance tests only
npm run test:mainnet       # All mainnet tests
```

Or run directly:

```bash
HARDHAT_CONFIG=hardhat.config.mainnet.ts npx hardhat test test/SaucerSwapForkTest.test.ts
HARDHAT_CONFIG=hardhat.config.mainnet.ts npx hardhat test test/BonzoForkTest.test.ts
```

### SaucerSwap V2 Tests (`SaucerSwapForkTest.test.ts`)

Interacts with SaucerSwap V2 and real HTS tokens (WHBAR, USDC) on mainnet:

| Test                  | What It Does                                                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Token metadata        | Reads real WHBAR and USDC name, symbol, decimals, totalSupply                                                                 |
| Contract verification | Checks WHBAR/USDC token existence on the fork                                                                                 |
| Swap (Foundry only)   | The actual WHBAR→USDC swap works in Foundry but is skipped in Hardhat due to an entity ID address limitation (see note below) |

### Bonzo Finance Tests (`BonzoForkTest.test.ts`)

Interacts with Bonzo Finance (Aave V2 fork) on mainnet:

| Test                   | What It Does                                                                                 |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| LendingPool exists     | Verifies Bonzo LendingPool has bytecode                                                      |
| USDC liquidity         | Reads real USDC liquidity in Bonzo (~7M USDC)                                                |
| Deposit WHBAR          | Deposits 5000 WHBAR as collateral, receives aWHBAR tokens                                    |
| Deposit + Account Data | Full flow: deposit, check collateral value, LTV (62.72%), borrowing capacity via real oracle |

> **Hardhat vs Foundry Limitation:** Smart contracts deployed via the Hedera SDK get entity ID-derived addresses (e.g., `0x...003c437A`). The Hardhat hedera-forking plugin may not fetch bytecode for non-HTS contracts at these addresses, which affects the SaucerSwap Router. The Foundry fork test handles these addresses correctly. For the complete SaucerSwap swap and Bonzo borrow tests working end-to-end, see the [Foundry advanced tutorial](../foundry/advanced-hts-fork-test-foundry/).

### Mainnet Addresses

| Contract/Token       | Hedera ID   | Address                                      |
| -------------------- | ----------- | -------------------------------------------- |
| SaucerSwap V2 Router | 0.0.3949434 | `0x00000000000000000000000000000000003c437A` |
| Bonzo LendingPool    | -           | `0x236897c518996163E7b313aD21D1C9fCC7BA1afc` |
| WHBAR                | 0.0.1456986 | `0x0000000000000000000000000000000000163B5a` |
| USDC (Native)        | 0.0.456858  | `0x000000000000000000000000000000000006f89a` |

---

## Resources

- [Hedera Forking Repository](https://github.com/hashgraph/hedera-forking)
- [Hedera Smart Contracts](https://github.com/hashgraph/hedera-smart-contracts)
- [HTS System Contract Precompiles](https://github.com/hashgraph/hedera-smart-contracts/tree/main/contracts/system-contracts/hedera-token-service)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Hedera Documentation](https://docs.hedera.com/)
- [Tutorial: Forking Hedera Network for Local Testing - Advanced HTS](https://docs.hedera.com/hedera/tutorials/smart-contracts/how-to-fork-the-hedera-network-with-hardhat-advanced-hts)

## License

MIT
