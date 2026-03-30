// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/htsSetup.sol";
import {IHederaTokenService} from "hedera-forking/IHederaTokenService.sol";
import {IERC20} from "hedera-forking/IERC20.sol";
import {HTSTokenManager} from "../src/HTSTokenManager.sol";

/// @title HTSForkTest
/// @notice Fork test suite for HTSTokenManager using hedera-forking emulation.
/// @dev Run with:
///   source .env
///   forge test --match-contract HTSForkTest \
///     --fork-url $HEDERA_RPC_URL \
///     --fork-block-number $HTS_FORK_BLOCK \
///     -vvv
///
///   CRITICAL: htsSetup() MUST be called in setUp() before any HTS
///   precompile interaction. This deploys the Solidity emulation layer at
///   address 0x167 so that HTS calls work in the forked environment.
///
///   Without htsSetup(), calls to 0x167 return 0xfe (InvalidFEOpcode)
///   because the Hedera system contract has no EVM bytecode on-chain.
contract HTSForkTest is Test {

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev HTS SUCCESS response code
    int32 constant SUCCESS = 22;

    // -----------------------------------------------------------------------
    // Configuration
    // -----------------------------------------------------------------------
    // IMPORTANT: Replace these with your deployed addresses after running
    // the deployment steps in the README.

    // Your deployed testnet contract:
    // https://hashscan.io/testnet/contract/0x22723B710D0A1Bdc83706Dd8085414c0570FaB8b
    address payable constant DEPLOYED_HTS_CONTRACT = payable(0x22723B710D0A1Bdc83706Dd8085414c0570FaB8b);
    // https://hashscan.io/testnet/token/0x000000000000000000000000000000000080d4f4
    address constant HTS_TOKEN = 0x000000000000000000000000000000000080d4f4;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    HTSTokenManager public htsManager;
    IERC20 public token;
    address public alice;
    address public bob;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------
    function setUp() public {
        // STEP 1: Initialize the HTS emulation layer.
        // This deploys the Solidity emulation contract at address 0x167
        // so HTS precompile calls work in the forked environment.
        // Without this line, all HTS calls revert with InvalidFEOpcode.
        htsSetup();

        // STEP 2: Bind to the deployed contracts on the fork.
        htsManager = HTSTokenManager(DEPLOYED_HTS_CONTRACT);
        token = IERC20(HTS_TOKEN);

        // STEP 3: Create test accounts and fund them.
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(DEPLOYED_HTS_CONTRACT, 100 ether);
    }

    /* =========================
          Token Info Tests
       ========================= */

    /// @notice Query token info via HTS precompile getTokenInfo.
    function test_GetTokenInfo() public {
        (int256 responseCode, IHederaTokenService.TokenInfo memory info) =
            htsManager.getTokenInfoPublic(HTS_TOKEN);

        assertEq(responseCode, int256(SUCCESS), "getTokenInfo should return SUCCESS");

        console.log("Token name:", info.token.name);
        console.log("Token symbol:", info.token.symbol);

        assertTrue(bytes(info.token.name).length > 0, "Token name should not be empty");
        assertTrue(bytes(info.token.symbol).length > 0, "Token symbol should not be empty");
    }

    /// @notice Query fungible-specific token info via HTS precompile.
    function test_GetFungibleTokenInfo() public {
        (int256 responseCode, IHederaTokenService.FungibleTokenInfo memory info) =
            htsManager.getFungibleTokenInfoPublic(HTS_TOKEN);

        assertEq(responseCode, int256(SUCCESS), "getFungibleTokenInfo should return SUCCESS");

        console.log("Fungible token decimals:", info.decimals);
    }

    /* =========================
        ERC-20 Interface Tests
       ========================= */

    /// @notice Read token name and symbol via ERC-20 interface.
    /// @dev HTS tokens expose ERC-20 methods through the HIP-719 proxy pattern.
    ///      The proxy at the token address delegates to 0x167, which the emulation
    ///      layer handles by fetching real data from the Mirror Node.
    function test_ReadNameAndSymbol() public view {
        string memory name = token.name();
        string memory symbol = token.symbol();

        console.log("Token name:", name);
        console.log("Token symbol:", symbol);

        assertEq(name, "DemoHTS");
        assertEq(symbol, "DHTS");
    }

    /// @notice Read token decimals via ERC-20 interface.
    function test_ReadDecimals() public view {
        uint8 decimals = token.decimals();
        console.log("Token decimals:", decimals);
        assertEq(decimals, 8);
    }

    /// @notice Read total supply via ERC-20 interface.
    function test_ReadTotalSupply() public view {
        uint256 totalSupply = token.totalSupply();
        console.log("Total supply:", totalSupply);
        // Token was created with initial supply of 0 (we mint separately)
        // Just verify the call succeeds
        assertGe(totalSupply, 0);
    }

    /// @notice Read the treasury (contract) balance via ERC-20 interface.
    function test_ReadTreasuryBalance() public view {
        uint256 balance = token.balanceOf(DEPLOYED_HTS_CONTRACT);
        console.log("Treasury balance:", balance);
        // Treasury should have some tokens if minting was done after deploy
        assertGe(balance, 0);
    }

    /* =========================
          Transfer Tests
       ========================= */

    /// @notice Use Foundry's deal() to set token balances, then test ERC-20 transfer.
    /// @dev deal() works with HTS tokens in fork mode because the emulation layer
    ///      maps storage slots correctly.
    function test_DealAndTransfer() public {
        // Give alice some HTS tokens using Foundry's deal cheatcode
        uint256 amount = 1000;
        deal(HTS_TOKEN, alice, amount);

        uint256 aliceBalance = token.balanceOf(alice);
        console.log("Alice balance after deal:", aliceBalance);
        assertEq(aliceBalance, amount);

        // Alice transfers to bob via ERC-20 interface
        vm.prank(alice);
        token.transfer(bob, 400);

        uint256 aliceAfter = token.balanceOf(alice);
        uint256 bobAfter = token.balanceOf(bob);

        console.log("Alice balance after transfer:", aliceAfter);
        console.log("Bob balance after transfer:", bobAfter);

        assertEq(aliceAfter, 600);
        assertEq(bobAfter, 400);
    }

    /// @notice Test approve and transferFrom via ERC-20 interface.
    function test_ApproveAndTransferFrom() public {
        // Give alice tokens
        deal(HTS_TOKEN, alice, 2000);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, 1000);

        // Bob transfers from alice
        vm.prank(bob);
        token.transferFrom(alice, bob, 500);

        assertEq(token.balanceOf(alice), 1500);
        assertEq(token.balanceOf(bob), 500);

        console.log("Alice balance after transferFrom:", token.balanceOf(alice));
        console.log("Bob balance after transferFrom:", token.balanceOf(bob));
    }

    /// @notice Transfer to multiple recipients.
    function test_TransferToMultipleRecipients() public {
        deal(HTS_TOKEN, alice, 5000);

        // Alice transfers to bob
        vm.prank(alice);
        token.transfer(bob, 2000);

        // Alice transfers to a third address
        address charlie = makeAddr("charlie");
        vm.prank(alice);
        token.transfer(charlie, 1000);

        assertEq(token.balanceOf(alice), 2000);
        assertEq(token.balanceOf(bob), 2000);
        assertEq(token.balanceOf(charlie), 1000);

        console.log("Alice:", token.balanceOf(alice));
        console.log("Bob:", token.balanceOf(bob));
        console.log("Charlie:", token.balanceOf(charlie));
    }

    /* =========================
        Fork State Verification
       ========================= */

    /// @notice Verify the fork is connected and the contract exists.
    function test_ConnectedToForkedNetwork() public view {
        uint256 blockNumber = block.number;
        console.log("Fork block number:", blockNumber);
        assertGt(blockNumber, 0, "Block number should be > 0 on a fork");
    }

    /// @notice Verify the HTSTokenManager has bytecode on the fork.
    function test_ContractHasBytecode() public view {
        uint256 codeSize;
        address contractAddr = DEPLOYED_HTS_CONTRACT;
        assembly {
            codeSize := extcodesize(contractAddr)
        }
        console.log("HTS manager code size:", codeSize);
        assertGt(codeSize, 0, "HTSTokenManager should have bytecode on the fork");
    }

    /// @notice Verify the HTS precompile has emulation bytecode after htsSetup().
    function test_HTSPrecompileHasEmulation() public view {
        uint256 htsCodeSize;
        address hts = address(0x167);
        assembly {
            htsCodeSize := extcodesize(hts)
        }
        console.log("HTS precompile (0x167) code size:", htsCodeSize);
        assertGt(htsCodeSize, 0, "HTS precompile should have emulation bytecode after htsSetup()");
    }

    /// @notice Verify the HTS token has the HIP-719 proxy bytecode on the fork.
    function test_TokenHasBytecode() public view {
        uint256 tokenCodeSize;
        address tokenAddr = HTS_TOKEN;
        assembly {
            tokenCodeSize := extcodesize(tokenAddr)
        }
        console.log("HTS token code size:", tokenCodeSize);
        assertGt(tokenCodeSize, 0, "HTS token should have proxy bytecode on the fork");
    }
}
