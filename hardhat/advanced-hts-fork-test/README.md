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
advanced-hts-fork-test/
├── contracts/
│   └── HTSTokenManager.sol    # HTS token management contract
├── scripts/
│   └── deploy.ts              # Deployment script (deploys contract + creates token)
├── test/
│   └── HTSTokenManager.test.ts # Fork tests for HTS operations
├── hardhat.config.ts          # Hardhat configuration
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
Account balance: 67044. 71699545 HBAR

--- Deploying HTSTokenManager ---
HTSTokenManager deployed to: 0x525F2a20563A052F7dC65df59106EC82f0584102
View on HashScan: https://hashscan.io/testnet/contract/0x525F2a20563A052F7dC65df59106EC82f0584102

--- Creating HTS Fungible Token ---
Creating token "TestForkToken" (TFT)...
Sending 15 HBAR for token creation...
createFungibleTokenPublic() tx hash: 0xe71eb1253d11120dc9db1c764070fdb13db0b25374c30f2f0bd2792d1eead3fb
HTS Token created at: 0x000000000000000000000000000000000073E8dC
View token on HashScan: https://hashscan.io/testnet/token/0x000000000000000000000000000000000073E8dC

Deployed at block number: 29968809

============================================================
DEPLOYMENT SUMMARY
============================================================
HTSTokenManager Contract: 0x525F2a20563A052F7dC65df59106EC82f0584102
HTS Token Address:          0x000000000000000000000000000000000073E8dC
Block Number:             29968809
============================================================

=== IMPORTANT ===
Update your hardhat.config.ts with:
  blockNumber: 29968809

Update your test file with:
  DEPLOYED_CONTRACT = "0x525F2a20563A052F7dC65df59106EC82f0584102"
  TOKEN_ADDRESS = "0x000000000000000000000000000000000073E8dC"
```

### 4. Update Configuration

After deployment, update the following files with the values from the deployment output:

**hardhat.config.ts:**

```typescript
blockNumber: 29968809, // Your deployment block number
```

**test/HTSTokenManager.test.ts:**

```typescript
const DEPLOYED_CONTRACT = "0x525F2a20563A052F7dC65df59106EC82f0584102";
const TOKEN_ADDRESS = "0x000000000000000000000000000000000073E8dC";
```

## Running Tests

Run the fork tests:

```bash
npm test
```

Example output:

```
  HTSTokenManager - HTS Forking Tests
    Token Info
Successfully retrieved token info
      ✔ should get token info for the pre-created token (870ms)
Successfully retrieved fungible token info
      ✔ should get fungible token info for the pre-created token (108ms)
Token Name:  TestForkToken
Token Symbol: TFT
Token Decimals: 0
Token Total Supply: 0
      ✔ should read token properties via ERC-20 interface (196ms)
    Token Minting
Minted 1000 tokens.   New total supply: 1000
      ✔ should mint tokens successfully (602ms)
First mint - New total supply: 500
Second mint - New total supply: 800
      ✔ should mint tokens multiple times and track total supply
Treasury balance before mint: 0
Treasury balance after mint: 2000
      ✔ should increase treasury balance after minting
    Token Transfers
Alice balance before transfer:   0
Alice balance after transfer: 1000
      ✔ should transfer tokens from treasury to alice (302ms)
Transferred 2000 to alice
Transferred 3000 to bob
Alice final balance: 2000
Bob final balance: 3000
      ✔ should transfer tokens to multiple recipients (275ms)
Initial total supply: 0
Minted 3000 tokens
Supply after mint: 3000
Transferred 1500 to alice
Alice balance:   1500
      ✔ should mint and then transfer in sequence
    Token Creation
Created new token at:   0x0000000000000000000000000000000000000408
      ✔ should create a new token via the contract (487ms)
    Fork Network Verification
Current fork block number: 29968809
      ✔ should be connected to a forked network
Contract at 0x525F2a20563A052F7dC65df59106EC82f0584102 has 17144 bytes of code
      ✔ should be interacting with real deployed contract
Token at 0x000000000000000000000000000000000073E8dC exists on the forked network
      ✔ should be able to access the pre-created token
Contract (treasury) balance: 100
      ✔ should verify contract is the token treasury

  14 passing (18s)
```

## Contract Overview

### HTSTokenManager. sol

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

## Resources

- [Hedera Forking Repository](https://github.com/hashgraph/hedera-forking)
- [Hedera Smart Contracts](https://github.com/hashgraph/hedera-smart-contracts)
- [HTS System Contract Precompiles](https://github.com/hashgraph/hedera-smart-contracts/tree/main/contracts/system-contracts/hedera-token-service)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Hedera Documentation](https://docs.hedera.com/)
- [Tutorial: Forking Hedera Network for Local Testing - Advanced HTS](https://docs.hedera.com/hedera/tutorials/smart-contracts/how-to-fork-the-hedera-network-with-hardhat-advanced-hts)

## License

MIT
