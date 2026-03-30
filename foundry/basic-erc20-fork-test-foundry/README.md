# Basic ERC-20 Fork Testing with Foundry

This project demonstrates fork testing on Hedera using Foundry. It shows how to deploy an ERC-20 token to Hedera testnet and then run tests against the deployed contract on a forked network.

## Overview

This example covers:

- Deploying an ERC-20 token contract to Hedera testnet
- Forking Hedera testnet locally using Foundry
- Testing against the deployed contract without spending gas
- Using impersonation (`vm.prank`) to act as any account
- Reading and modifying state on the forked network

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- An ECDSA account from the [Hedera Portal](https://portal.hedera.com/) with testnet HBAR
- Basic understanding of Solidity

## Project Structure

```
basic-erc20-fork-test-foundry/
├── src/
│   └── ERC20Token.sol         # ERC-20 token contract
├── script/
│   └── Deploy.s.sol           # Deployment script
├── test/
│   └── ERC20Token.t.sol       # Fork tests
├── lib/                       # Dependencies (forge install)
├── foundry.toml               # Foundry configuration
├── remappings.txt             # Import remappings
├── .env                       # Environment variables (not committed)
└── README.md
```

## Setup

### 1. Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install hashgraph/hedera-forking
```

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

Note that these variables will only be used for the original deployment of the contract to the testnet. The private key is not needed for the forked tests since we will be impersonating accounts.

Load the environment variables:

```bash
source .env
```

### 4. Build the Project

```bash
forge build
```

## Deployment

Deploy the ERC-20 token to Hedera testnet:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $HEDERA_RPC_URL --broadcast
```

Example output:

```
Deploying contracts with the account:  0xA98556A4deeB07f21f8a66093989078eF86faa30
Account balance: 67028157017920000000000
ERC20Token deployed to: 0xfC7D2FB1D5a9Be5D6182cBf3F283140d007CdcD4
View on HashScan: https://hashscan.io/testnet/contract/ 0xfC7D2FB1D5a9Be5D6182cBf3F283140d007CdcD4

=== IMPORTANT ===
Save this contract address for your fork tests!
Update DEPLOYED_CONTRACT in your test file with this address
```

After deployment, update the `DEPLOYED_CONTRACT` address in `test/ERC20Token.t.sol`.

## Running Tests

Run the fork tests:

```bash
forge test --fork-url $HEDERA_RPC_URL -vvv
```

Pin to a specific block for reproducible tests:

```bash
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 33426353 -vvv
```

Example output:

```
Ran 15 tests for test/ERC20Token.t.sol:ERC20TokenForkTest
[PASS] test_AllowOwnerToMint() (gas: 49526)
[PASS] test_ApproveAndCheckAllowance() (gas: 77316)
[PASS] test_ConnectedToForkedNetwork() (gas: 3725)
Logs:
  Current fork block number: 33426353

[PASS] test_FailTransferFromWithoutApproval() (gas: 53875)
[PASS] test_FailTransferWithInsufficientBalance() (gas: 16977)
[PASS] test_HandleMultipleTransfers() (gas: 83137)
[PASS] test_InteractingWithRealDeployedContract() (gas: 6315)
Logs:
  Contract code size: 4380

[PASS] test_ReadDecimals() (gas: 5930)
[PASS] test_ReadNameAndSymbol() (gas: 18696)
[PASS] test_ReadOwnerBalance() (gas: 14130)
Logs:
  Owner balance: 10000000000000000000000

[PASS] test_ReadTotalSupply() (gas: 11401)
Logs:
  Total supply on testnet: 10000000000000000000000

[PASS] test_RejectMintingFromNonOwner() (gas: 14536)
[PASS] test_TrackSupplyChangesAfterMinting() (gas: 48071)
[PASS] test_TransferFromAfterApproval() (gas: 112142)
[PASS] test_TransferFromOwnerToAlice() (gas: 47497)
Suite result: ok. 15 passed; 0 failed; 0 skipped; finished in 3.66s (2.22s CPU time)

Ran 1 test suite in 6.34s (3.66s CPU time): 15 tests passed, 0 failed, 0 skipped (15 total tests)
```

## Contract Overview

### ERC20Token.sol

A basic ERC-20 token using OpenZeppelin contracts:

| Function                     | Description                            |
| ---------------------------- | -------------------------------------- |
| `name()`                     | Returns "MyToken"                      |
| `symbol()`                   | Returns "MTK"                          |
| `decimals()`                 | Returns 18                             |
| `totalSupply()`              | Returns total token supply             |
| `balanceOf(address)`         | Returns token balance of an account    |
| `transfer(address, uint256)` | Transfers tokens to a recipient        |
| `approve(address, uint256)`  | Approves a spender                     |
| `transferFrom(... )`         | Transfers tokens on behalf of an owner |
| `mint(address, uint256)`     | Mints new tokens (onlyOwner)           |

## How Fork Testing Works

### Why Fork Testing?

1. **Real-world state** - Test against actual deployed contract state
2. **No gas costs** - Tests run locally, no testnet transactions
3. **Impersonation** - Act as any account without their private key
4. **Safe experimentation** - Changes only affect the local fork

### Key Foundry Cheatcodes

#### Impersonation with `vm.prank`

```solidity
// Impersonate an address for the next call
vm.prank(ownerAddress);
token.mint(alice, 1000 ether);

// Impersonate for multiple calls
vm.startPrank(ownerAddress);
token.mint(alice, 500 ether);
token.transfer(bob, 200 ether);
vm.stopPrank();
```

#### Funding Accounts with `vm.deal`

```solidity
// Fund an account with 100 HBAR
vm. deal(accountAddress, 100 ether);
```

#### Creating Test Accounts with `makeAddr`

```solidity
address alice = makeAddr("alice");
address bob = makeAddr("bob");
```

### Local vs. Remote State

| Action                     | Affects Local Fork | Affects Testnet |
| -------------------------- | ------------------ | --------------- |
| Read balances              | ✅ (cached)        | ❌ (read-only)  |
| Transfer tokens            | ✅                 | ❌              |
| Mint new tokens            | ✅                 | ❌              |
| Deploy new contracts       | ✅                 | ❌              |
| Impersonate accounts       | ✅                 | ❌              |
| Changes persist after test | ❌ (reset)         | N/A             |

## Troubleshooting

### Test Fails with "Revert" on setUp

Ensure the `blockNumber` you're forking from is >= the block where your contract was deployed.

```bash
# This will fail if contract was deployed at block 29970059
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 29970058

# This will work
forge test --fork-url $HEDERA_RPC_URL --fork-block-number 29970059
```

### Rate Limiting Errors

If you hit RPC rate limits, reduce fuzz test runs in `foundry.toml`:

```toml
[profile.default. fuzz]
runs = 10
```

### Contract Address Mismatch

Make sure the `DEPLOYED_CONTRACT` address in your test file matches your actual deployed contract.

## Configuration

### foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
ffi = true
solc = "0.8.33"

[rpc_endpoints]
testnet = "${HEDERA_RPC_URL}"
```

## Dependencies

| Package                  | Purpose                     |
| ------------------------ | --------------------------- |
| `forge-std`              | Foundry standard library    |
| `openzeppelin-contracts` | ERC-20 implementation       |
| `hedera-forking`         | Hedera fork testing support |

## Resources

- [Hedera Forking Repository](https://github.com/hashgraph/hedera-forking)
- [Foundry Book](https://book.getfoundry. sh/)
- [Foundry Fork Testing](https://book.getfoundry.sh/forge/fork-testing)
- [OpenZeppelin Contracts](https://docs.openzeppelin. com/contracts)
- [Hedera Documentation](https://docs.hedera.com/)

## License

MIT
