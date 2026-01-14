// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract ERC20TokenForkTest is Test {
    // Your deployed testnet contract:
    // https://hashscan.io/testnet/contract/0xfC7D2FB1D5a9Be5D6182cBf3F283140d007CdcD4
    address constant DEPLOYED_CONTRACT =
        0xfC7D2FB1D5a9Be5D6182cBf3F283140d007CdcD4;

    ERC20Token public token;
    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        // Bind to the deployed contract on the forked network
        token = ERC20Token(DEPLOYED_CONTRACT);

        // Get the real owner from the deployed contract
        owner = token.owner();

        // Create test accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Fund test accounts
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    /* =========================
            Basic Info
       ========================= */

    function test_ReadNameAndSymbol() public view {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
    }

    function test_ReadDecimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_ReadTotalSupply() public view {
        uint256 totalSupply = token.totalSupply();
        console.log("Total supply on testnet:", totalSupply);
        assertGt(totalSupply, 0);
    }

    function test_ReadOwnerBalance() public view {
        uint256 balance = token.balanceOf(owner);
        console.log("Owner balance:", balance);
        assertGt(balance, 0);
    }

    /* =========================
            Ownership
       ========================= */

    function test_RejectMintingFromNonOwner() public {
        // Alice (not the owner) tries to mint → should revert
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }

    function test_AllowOwnerToMint() public {
        uint256 balanceBefore = token.balanceOf(alice);

        // Impersonate the real owner to mint
        vm.prank(owner);
        token.mint(alice, 500 ether);

        uint256 balanceAfter = token.balanceOf(alice);
        assertEq(balanceAfter, balanceBefore + 500 ether);
    }

    /* =========================
            Transfers
       ========================= */

    function test_TransferFromOwnerToAlice() public {
        uint256 amount = 100 ether;
        uint256 balanceBefore = token.balanceOf(alice);

        // Transfer from owner
        vm.prank(owner);
        token.transfer(alice, amount);

        uint256 balanceAfter = token.balanceOf(alice);
        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_HandleMultipleTransfers() public {
        // Mint tokens to alice first
        vm.prank(owner);
        token.mint(alice, 1000 ether);

        uint256 aliceInitial = token.balanceOf(alice);
        uint256 bobInitial = token.balanceOf(bob);

        // Alice transfers to bob
        vm.prank(alice);
        token.transfer(bob, 300 ether);

        assertEq(token.balanceOf(alice), aliceInitial - 300 ether);
        assertEq(token.balanceOf(bob), bobInitial + 300 ether);
    }

    function test_FailTransferWithInsufficientBalance() public {
        // Bob has no tokens initially, should fail
        vm.prank(bob);
        vm.expectRevert();
        token.transfer(alice, 100 ether);
    }

    /* =========================
          Allowances
       ========================= */

    function test_ApproveAndCheckAllowance() public {
        // Mint tokens to alice
        vm.prank(owner);
        token.mint(alice, 1000 ether);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, 500 ether);

        assertEq(token.allowance(alice, bob), 500 ether);
    }

    function test_TransferFromAfterApproval() public {
        // Mint tokens to alice
        vm.prank(owner);
        token.mint(alice, 1000 ether);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, 500 ether);

        uint256 aliceBefore = token.balanceOf(alice);

        // Bob transfers from alice to himself
        vm.prank(bob);
        token.transferFrom(alice, bob, 200 ether);

        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.balanceOf(alice), aliceBefore - 200 ether);
        assertEq(token.allowance(alice, bob), 300 ether);
    }

    function test_FailTransferFromWithoutApproval() public {
        // Mint tokens to alice but no approval for bob
        vm.prank(owner);
        token.mint(alice, 1000 ether);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 100 ether);
    }

    /* =========================
         Supply Changes
       ========================= */

    function test_TrackSupplyChangesAfterMinting() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(owner);
        token.mint(alice, 5000 ether);

        uint256 supplyAfter = token.totalSupply();
        assertEq(supplyAfter, supplyBefore + 5000 ether);
    }

    /* =========================
        Fork Verification
       ========================= */

    function test_ConnectedToForkedNetwork() public view {
        uint256 blockNumber = block.number;
        console.log("Current fork block number:", blockNumber);
        assertGt(blockNumber, 0);
    }

    function test_InteractingWithRealDeployedContract() public view {
        // Verify we're reading from the actual deployed contract
        uint256 codeSize;
        address contractAddr = DEPLOYED_CONTRACT;
        assembly {
            codeSize := extcodesize(contractAddr)
        }
        assertGt(codeSize, 0);
        console.log("Contract code size:", codeSize);
    }
}
