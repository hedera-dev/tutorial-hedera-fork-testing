# Advanced HTS Fork Testing with Foundry

This project demonstrates fork testing **Hedera Token Service (HTS)** smart contracts using Foundry. It shows how to deploy an HTS fungible token via the system contract precompile at `0x167` and run fork tests using the [hedera-forking](https://github.com/hashgraph/hedera-forking) emulation layer.

## Overview

This example covers:

- Deploying an HTSTokenManager contract that creates native HTS tokens
- Forking Hedera testnet locally using Foundry
- Activating the HTS emulation layer with `htsSetup()`
- Testing HTS operations: token info queries, minting, and transfers
- Understanding why `ffi = true` is required and how FFI fetches real data from the Mirror Node

> **What makes this different from the basic ERC-20 tutorial?**
> Standard ERC-20 tokens on Hedera work in fork testing out of the box. HTS tokens interact with the system contract at `0x167`, which returns `0xfe` (InvalidFEOpcode) in a standard fork because the contract is a native Hedera service, not EVM bytecode. The `hedera-forking` library provides a Solidity emulation layer that intercepts these calls and fetches real token data from the Hedera Mirror Node.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- An ECDSA account from the [Hedera Portal](https://portal.hedera.com/) with testnet HBAR (at least 20 HBAR for token creation fees)
- Basic understanding of Solidity and [Hedera Token Service](https://docs.hedera.com/hedera/sdks-and-apis/sdks/token-service)

## Project Structure

```
advanced-hts-fork-test-foundry/
├── src/
│   └── HTSTokenManager.sol      # HTS token manager (create, mint, transfer, query)
├── script/
│   └── DeployHTS.s.sol           # Deployment script (deploys manager + creates HTS token)
├── test/
│   ├── HTSForkTest.t.sol         # Fork tests with HTS emulation (testnet)
│   └── SaucerSwapForkTest.t.sol  # Real-world mainnet fork test (SaucerSwap + USDC)
├── lib/                          # Dependencies (forge install)
├── foundry.toml                  # Foundry configuration (ffi = true required)
├── remappings.txt                # Import remappings
├── .env                          # Environment variables (not committed)
└── README.md
```

## Setup

### 1. Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install hashgraph/hedera-forking
```

> **Note:** `hedera-forking` requires `forge-std >= v1.8.0`. If you're on an older project, run `forge update lib/forge-std` first.

### 2. Configure Remappings

Create `remappings.txt`:

```txt
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
hedera-forking/=lib/hedera-forking/contracts/
forge-std/=lib/forge-std/src/
```

### 3. Set Environment Variables

Create a `.env` file:

```bash
HEDERA_RPC_URL=https://testnet.hashio.io/api
HEDERA_PRIVATE_KEY=0x-your-hex-encoded-private-key
```

> **Important:** The private key must be hex-encoded ECDSA. ED25519 keys are not supported by EVM tools. You can get an ECDSA testnet account at [portal.hedera.com](https://portal.hedera.com/).

Load the environment variables:

```bash
source .env
```

### 4. Build the Project

```bash
forge build
```

## Deployment

Deployment is a two-step process because `forge script` simulates transactions locally before broadcasting, and the HTS precompile at `0x167` has no EVM bytecode for local simulation. Step 1 deploys the contract; Step 2 creates the HTS token by sending a transaction directly to the RPC.

> Make sure your deployer account has at least 20 HBAR (15 HBAR for the HTS token creation fee + gas).

### Step 1: Deploy the HTSTokenManager Contract

```bash
forge script script/DeployHTS.s.sol:DeployHTSScript --rpc-url $HEDERA_RPC_URL --broadcast -vvv
```

Example output:

```
=== Deployment Successful ===
HTSTokenManager deployed to: 0x22723B710D0A1Bdc83706Dd8085414c0570FaB8b
Block number: 33427480
```

Save the contract address — you'll need it for the next step.

### Step 2: Create the HTS Token

Use `cast send` to call `createFungibleTokenPublic` directly on the deployed contract. Replace `CONTRACT_ADDRESS` with the address from Step 1:

```bash
export CONTRACT_ADDRESS=0x22723B710D0A1Bdc83706Dd8085414c0570FaB8b
```

```bash
cast send $CONTRACT_ADDRESS \
  'createFungibleTokenPublic(string,string)' 'DemoHTS' 'DHTS' \
  --value 15ether \
  --rpc-url $HEDERA_RPC_URL \
  --private-key $HEDERA_PRIVATE_KEY
```

This sends a transaction directly to Hedera (no local simulation), so the HTS precompile at `0x167` is handled natively by the consensus nodes.

### Step 3: Get the Token Address

```bash
cast call $CONTRACT_ADDRESS 'tokenAddress()' --rpc-url $HEDERA_RPC_URL
```

This returns the HTS token address as a hex-encoded 32-byte value. Extract the 20-byte address (last 40 hex chars):

```bash
cast abi-decode 'tokenAddress()(address)' $(cast call $CONTRACT_ADDRESS 'tokenAddress()' --rpc-url $HEDERA_RPC_URL)
```

### Step 4: Get the Block Number

Note the block number from your `cast send` transaction output, or query it:

```bash
cast block-number --rpc-url $HEDERA_RPC_URL
```

### Step 5: Update Test Constants

Update the two address constants in `test/HTSForkTest.t.sol`:

```solidity
address constant DEPLOYED_HTS_CONTRACT = 0x...; // HTSTokenManager address
address constant HTS_TOKEN = 0x...;              // HTS Token address
```

## Running Tests

Run the fork tests:

```bash
forge test --fork-url $HEDERA_RPC_URL -vvv
```

Pin to a specific block for reproducible tests:

```bash
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 33427481 -vvv
```

Example output:

```
Ran 13 tests for test/HTSForkTest.t.sol:HTSForkTest
[PASS] test_ApproveAndTransferFrom() (gas: 1788900)
Logs:
  Alice balance after transferFrom: 1500
  Bob balance after transferFrom: 500

[PASS] test_ConnectedToForkedNetwork() (gas: 3768)
Logs:
  Fork block number: 33427571

[PASS] test_ContractHasBytecode() (gas: 6379)
Logs:
  HTS manager code size: 11358

[PASS] test_DealAndTransfer() (gas: 1688928)
Logs:
  Alice balance after deal: 1000
  Alice balance after transfer: 600
  Bob balance after transfer: 400

[PASS] test_GetFungibleTokenInfo() (gas: 1413178)
Logs:
  Fungible token decimals: 8

[PASS] test_GetTokenInfo() (gas: 1403795)
Logs:
  Token name: DemoHTS
  Token symbol: DHTS

[PASS] test_HTSPrecompileHasEmulation() (gas: 6422)
Logs:
  HTS precompile (0x167) code size: 100769

[PASS] test_ReadDecimals() (gas: 1204125)
Logs:
  Token decimals: 8

[PASS] test_ReadNameAndSymbol() (gas: 1216338)
Logs:
  Token name: DemoHTS
  Token symbol: DHTS

[PASS] test_ReadTotalSupply() (gas: 1204165)
Logs:
  Total supply: 0

[PASS] test_ReadTreasuryBalance() (gas: 2055646)
Logs:
  Treasury balance: 0

[PASS] test_TokenHasBytecode() (gas: 6425)
Logs:
  HTS token code size: 147

[PASS] test_TransferToMultipleRecipients() (gas: 1853280)
Logs:
  Alice: 2000
  Bob: 2000
  Charlie: 1000

Suite result: ok. 13 passed; 0 failed; 0 skipped; finished in 13.67s (87.31s CPU time)

Ran 1 test suite in 15.53s (13.67s CPU time): 13 tests passed, 0 failed, 0 skipped (13 total tests)
```

## Bonus: Real-World SaucerSwap Mainnet Fork Test

The repo includes a bonus test file `test/SaucerSwapForkTest.t.sol` that demonstrates forking **Hedera mainnet** and interacting with live SaucerSwap V2 contracts and real HTS tokens (WHBAR, USDC).

This showcases one of the most compelling use cases: testing against production DeFi contracts without spending real HBAR.

### Run the SaucerSwap Tests

```bash
forge test --match-contract SaucerSwapForkTest --fork-url https://mainnet.hashio.io/api -vvv
```

### What It Tests

| Test | What It Does |
| ---- | ------------ |
| `test_ReadWHBARMetadata` | Reads real WHBAR name, symbol, decimals, totalSupply from mainnet |
| `test_ReadUSDCMetadata` | Reads real USDC (Circle-issued) metadata from mainnet |
| `test_DealUSDCToTrader` | Uses `deal()` to create 1000 USDC from nothing on the fork |
| `test_DealWHBARAndTransfer` | Uses `deal()` for WHBAR, then ERC-20 transfer between accounts |
| `test_SwapWHBARForUSDCViaSaucerSwap` | **Real swap**: 10 WHBAR -> USDC through SaucerSwap V2 at live mainnet pricing |
| `test_ReadRealMainnetBalances` | Reads the WHBAR contract's own balance from real mainnet state |
| `test_SaucerSwapRouterExists` | Verifies the SaucerSwap V2 Router has bytecode on the fork |
| `test_OnMainnetFork` | Verifies chain ID is 295 (Hedera mainnet) |

### How the Real Swap Works

The `test_SwapWHBARForUSDCViaSaucerSwap` test executes a real swap through SaucerSwap V2's `exactInput` function using real liquidity pools on the forked mainnet:

1. `deal(WHBAR, trader, 10e8)` - Creates 10 WHBAR on the fork (no real tokens needed)
2. `whbar.approve(router, amount)` - Trader approves the SaucerSwap router
3. `exactInput(path: WHBAR->0.15%->USDC)` - Calls the real router contract with the swap path
4. The router interacts with the real WHBAR/USDC pool (real liquidity, real pricing)
5. The trader receives USDC at the current mainnet exchange rate

The test account doesn't need real HBAR or tokens on mainnet. `deal()` creates balances locally, and all swap execution happens on the fork. No mainnet transactions are ever sent.

### Mainnet Addresses Used

| Contract/Token | Hedera ID | EVM Address |
| -------------- | --------- | ----------- |
| SaucerSwap V2 Router | `0.0.3949434` | `0x00000000000000000000000000000000003c437A` |
| WHBAR | `0.0.1456986` | `0x0000000000000000000000000000000000163B5a` |
| USDC (Native) | `0.0.456858` | `0x000000000000000000000000000000000006f89a` |

> **Source:** [SaucerSwap Contract Deployments](https://docs.saucerswap.finance/developerx/contract-deployments)

---

## Contract Overview

### HTSTokenManager.sol

A contract that manages HTS fungible tokens via the Hedera Token Service precompile at `0x167`:

| Function                            | Description                                         |
| ----------------------------------- | --------------------------------------------------- |
| `createFungibleTokenPublic()`       | Creates an HTS fungible token (requires HBAR fee)   |
| `mintTokenPublic(token, amount)`    | Mints additional tokens (contract holds supply key) |
| `transferTokenPublic(...)`          | Transfers HTS tokens between accounts               |
| `getTokenInfoPublic(token)`         | Queries full token info via HTS precompile          |
| `getFungibleTokenInfoPublic(token)` | Queries fungible-specific token info                |
| `tokenAddress`                      | Address of the last created token                   |

### HTSForkTest.t.sol - Test Categories

Mirroring the Hardhat advanced tutorial's test structure:

| Category              | Tests                                                                                                                  | What's Covered                                       |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Token Info**        | `test_GetTokenInfo`, `test_GetFungibleTokenInfo`                                                                       | Query HTS precompile for token metadata              |
| **ERC-20 Interface**  | `test_ReadNameAndSymbol`, `test_ReadDecimals`, `test_ReadTotalSupply`, `test_ReadTreasuryBalance`                      | Read HTS token properties via the HIP-719 proxy      |
| **Transfers**         | `test_DealAndTransfer`, `test_ApproveAndTransferFrom`, `test_TransferToMultipleRecipients`                             | ERC-20 transfer, approve, transferFrom on HTS tokens |
| **Fork Verification** | `test_ConnectedToForkedNetwork`, `test_ContractHasBytecode`, `test_HTSPrecompileHasEmulation`, `test_TokenHasBytecode` | Verify fork state and emulation layer                |

> **Note on minting/transfers via HTS precompile:** The Hardhat tutorial tests `mintToken` and `transferToken` through the HTS precompile because the Hardhat plugin intercepts at the JSON-RPC level. In Foundry, the emulation layer excels at read operations and ERC-20 level interactions. For write operations, use Foundry's `deal()` cheatcode to set balances and standard ERC-20 methods (`transfer`, `approve`, `transferFrom`) which work through the HIP-719 proxy redirect pattern.

### Key Concepts

**HTS Precompile (0x167):** Hedera's Token Service is a native system contract at address `0x167`. Unlike standard EVM contracts, it has no on-chain bytecode - it's implemented in the consensus node software. When you fork Hedera and call `0x167`, the JSON-RPC relay returns `0xfe` (the INVALID opcode), and your test crashes with `InvalidFEOpcode`.

**htsSetup():** This single function call in your test's `setUp()` deploys the `hedera-forking` emulation layer at `0x167`. After this call, HTS function calls work because they hit a Solidity contract that fetches real token data from the Hedera Mirror Node via FFI.

**FFI (ffi = true):** The emulation layer shells out to `curl` to query the Mirror Node REST API for real token data (balances, metadata, associations). This is why `ffi = true` is required in `foundry.toml`. FFI is a Foundry cheatcode that allows contracts to execute shell commands.

## How HTS Fork Testing Works

### The Problem

```
Your test calls token.balanceOf()
  → Anvil fetches bytecode at 0x167
    → JSON-RPC relay returns 0xfe (no EVM bytecode)
      → EvmError: InvalidFEOpcode ❌
```

### The Solution (with hedera-forking)

```
htsSetup() deploys emulation at 0x167
  → Your test calls token.balanceOf()
    → Anvil finds emulation bytecode at 0x167
      → Emulation uses FFI + curl to fetch from Mirror Node
        → Returns real token data ✅
```

### Why This Is Different from ERC-20 Fork Testing

| Aspect           | ERC-20 (Basic Tutorial)          | HTS (This Tutorial)                     |
| ---------------- | -------------------------------- | --------------------------------------- |
| Contract type    | Standard EVM bytecode            | Native Hedera system contract           |
| Fork behavior    | Works out of the box             | Returns `0xfe` without emulation        |
| Setup required   | None beyond standard fork        | `htsSetup()` in `setUp()`               |
| `ffi` setting    | Not required                     | `ffi = true` required in `foundry.toml` |
| Data source      | Fork state from RPC              | Mirror Node via FFI + curl              |
| Token operations | ERC-20 standard (transfer, etc.) | HTS precompile (create, mint, transfer) |

## Troubleshooting

### `EvmError: InvalidFEOpcode`

This means `htsSetup()` was not called or did not complete. Make sure it's the **first line** in your `setUp()` function, before any HTS interaction.

### `StateChangeDuringStaticCall`

This means `vm.allowCheatcodes(0x167)` was not set. This happens automatically inside `htsSetup()` — make sure it runs before any HTS calls.

### Test Fails with "Revert" on setUp

Ensure the block number you're forking from is **>=** the block where your contracts were deployed.

```bash
# This will fail if contract was deployed at block 30000100
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 30000099

# This will work
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 30000100
```

### FFI-Related Errors

- Ensure `ffi = true` is set in `foundry.toml`
- Ensure `curl` is available on your system (Unix/Mac). Windows users need PowerShell.
- Check your network connection — the emulation layer needs to reach the Hedera Mirror Node

### Rate Limiting Errors

If you hit Mirror Node rate limits, the `hedera-forking` library caches responses per endpoint. Pinning to a specific block also helps because the same block always returns the same state.

### Contract Address Mismatch

Make sure `DEPLOYED_HTS_CONTRACT` and `HTS_TOKEN` in your test file match your actual deployed addresses from the deployment script output.

## Configuration

### foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
ffi = true       # Required for HTS emulation (Mirror Node queries via curl)
solc = "0.8.33"

[rpc_endpoints]
testnet = "${HEDERA_RPC_URL}"
```

> **Security note:** `ffi = true` allows Foundry to execute shell commands. Only enable this in test profiles, never in production deployment scripts.

## Dependencies

| Package                  | Purpose                                       |
| ------------------------ | --------------------------------------------- |
| `forge-std`              | Foundry standard library (>= v1.8.0 required) |
| `openzeppelin-contracts` | Base contract utilities                       |
| `hedera-forking`         | HTS emulation layer for fork testing          |

## Resources

- [Hedera Forking Repository](https://github.com/hashgraph/hedera-forking)
- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry Fork Testing](https://book.getfoundry.sh/forge/fork-testing)
- [Hedera Token Service Documentation](https://docs.hedera.com/hedera/sdks-and-apis/sdks/token-service)
- [Hedera Documentation](https://docs.hedera.com/)
- [Basic ERC-20 Fork Test Tutorial](../basic-erc20-fork-test-foundry/)

## License

MIT
