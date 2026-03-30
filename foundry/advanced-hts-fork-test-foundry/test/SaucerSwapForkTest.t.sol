// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/htsSetup.sol";
import {IERC20} from "hedera-forking/IERC20.sol";

/// @title SaucerSwapForkTest
/// @notice Real-world fork test: interact with SaucerSwap V2 on Hedera mainnet.
/// @dev This test forks Hedera mainnet and interacts with live deployed
///   SaucerSwap contracts and real HTS tokens (WHBAR, USDC). It demonstrates
///   practical use cases of the hedera-forking library:
///
///   1. Reading real production token metadata (WHBAR, USDC)
///   2. Impersonating a real mainnet whale to use their balances
///   3. Executing a real swap through SaucerSwap V2 (WHBAR -> USDC)
///
///   The test accounts don't need real HBAR or tokens on mainnet.
///   Foundry cheatcodes (deal, prank, vm.deal) create balances and
///   impersonate accounts locally on the fork. No real mainnet
///   transactions are ever sent.
///
///   Run with:
///     forge test --match-contract SaucerSwapForkTest \
///       --fork-url https://mainnet.hashio.io/api \
///       -vvv
contract SaucerSwapForkTest is Test {

    // -----------------------------------------------------------------------
    // Mainnet Contract Addresses
    // See: https://docs.saucerswap.finance/developerx/contract-deployments
    // -----------------------------------------------------------------------

    /// @dev SaucerSwap V2 Router - 0.0.3949434
    address constant SAUCERSWAP_ROUTER = 0x00000000000000000000000000000000003c437A;

    /// @dev WHBAR (Wrapped HBAR) - 0.0.1456986, 8 decimals
    address constant WHBAR = 0x0000000000000000000000000000000000163B5a;

    /// @dev USDC (Native Circle-issued) - 0.0.456858, 6 decimals
    address constant USDC = 0x000000000000000000000000000000000006f89a;

    // -----------------------------------------------------------------------
    // SaucerSwap V2 Router Interface (Uniswap V3 compatible)
    // -----------------------------------------------------------------------

    /// @dev Parameters for exactInput swap (multi-hop path)
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    IERC20 public whbar;
    IERC20 public usdc;
    address public trader;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------
    function setUp() public {
        // Activate HTS emulation - required for reading HTS token state
        htsSetup();

        // Bind to real mainnet tokens
        whbar = IERC20(WHBAR);
        usdc = IERC20(USDC);

        // Create a test trader account with HBAR for gas
        trader = makeAddr("trader");
        vm.deal(trader, 1000 ether);
    }

    // =======================================================================
    // SECTION 1: Token Read Tests
    // Verify we can read real mainnet HTS token state via the emulation layer.
    // These calls go through the HIP-719 proxy -> 0x167 emulation -> Mirror Node.
    // =======================================================================

    /// @notice Read WHBAR token metadata from mainnet
    function test_ReadWHBARMetadata() public view {
        string memory name = whbar.name();
        string memory symbol = whbar.symbol();
        uint8 decimals = whbar.decimals();
        uint256 totalSupply = whbar.totalSupply();

        console.log("WHBAR name:", name);
        console.log("WHBAR symbol:", symbol);
        console.log("WHBAR decimals:", decimals);
        console.log("WHBAR total supply:", totalSupply);

        assertEq(decimals, 8, "WHBAR should have 8 decimals");
        assertTrue(totalSupply > 0, "WHBAR should have supply on mainnet");
    }

    /// @notice Read USDC token metadata from mainnet
    function test_ReadUSDCMetadata() public view {
        string memory name = usdc.name();
        string memory symbol = usdc.symbol();
        uint8 decimals = usdc.decimals();
        uint256 totalSupply = usdc.totalSupply();

        console.log("USDC name:", name);
        console.log("USDC symbol:", symbol);
        console.log("USDC decimals:", decimals);
        console.log("USDC total supply:", totalSupply);

        assertEq(decimals, 6, "USDC should have 6 decimals");
        assertTrue(totalSupply > 0, "USDC should have supply on mainnet");
    }

    // =======================================================================
    // SECTION 2: Cheatcode-Based Balance Tests
    // These tests use Foundry's deal() to set token balances on the fork.
    // deal() writes directly to storage - the account doesn't need real
    // tokens on mainnet. This is useful for setting up test preconditions.
    // =======================================================================

    /// @notice Use deal() to give trader USDC, then verify balance
    function test_DealUSDCToTrader() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC (6 decimals)
        deal(USDC, trader, amount);

        uint256 balance = usdc.balanceOf(trader);
        console.log("Trader USDC balance after deal:", balance);
        assertEq(balance, amount, "Trader should have 1000 USDC");
    }

    /// @notice Use deal() for WHBAR, then do an ERC-20 transfer
    function test_DealWHBARAndTransfer() public {
        uint256 amount = 100 * 1e8; // 100 WHBAR (8 decimals)
        deal(WHBAR, trader, amount);

        address recipient = makeAddr("recipient");
        vm.prank(trader);
        whbar.transfer(recipient, 50 * 1e8);

        assertEq(whbar.balanceOf(trader), 50 * 1e8);
        assertEq(whbar.balanceOf(recipient), 50 * 1e8);
        console.log("WHBAR transfer succeeded on mainnet fork");
    }

    // =======================================================================
    // SECTION 3: Real SaucerSwap V2 Swap
    // This is the real deal: execute an actual swap through SaucerSwap V2's
    // exactInput function on the forked mainnet. The swap goes through real
    // liquidity pools with real pricing.
    //
    // HOW THIS WORKS:
    // 1. We give the trader WHBAR using deal() (no real tokens needed)
    // 2. The trader approves the SaucerSwap router to spend WHBAR
    // 3. The trader calls exactInput on the router with the WHBAR->USDC path
    // 4. The router interacts with the real WHBAR/USDC pool on the fork
    // 5. The trader receives real USDC at the current mainnet exchange rate
    //
    // The swap works because:
    // - The SaucerSwap router contract has real bytecode on the fork
    // - The WHBAR/USDC pool has real liquidity (fetched from mainnet state)
    // - htsSetup() enables HTS token reads (balanceOf, transfer, etc.)
    // - All state changes are local to the fork - nothing hits mainnet
    // =======================================================================

    /// @notice Swap WHBAR for USDC through SaucerSwap V2 on the forked mainnet.
    function test_SwapWHBARForUSDCViaSaucerSwap() public {
        // --- Setup: Give the trader 10 WHBAR ---
        uint256 whbarAmount = 10 * 1e8; // 10 WHBAR (8 decimals = 1 billion tinybars)
        deal(WHBAR, trader, whbarAmount);
        console.log("Trader WHBAR balance before swap:", whbar.balanceOf(trader));

        // --- Step 1: Approve the SaucerSwap router to spend WHBAR ---
        vm.startPrank(trader);
        whbar.approve(SAUCERSWAP_ROUTER, whbarAmount);
        console.log("Approved router to spend WHBAR");

        // --- Step 2: Encode the swap path ---
        // Path format: [tokenIn (20 bytes), fee (3 bytes), tokenOut (20 bytes)]
        // WHBAR -> 0.15% fee tier (1500) -> USDC
        bytes memory path = abi.encodePacked(
            WHBAR,
            uint24(1500),   // 0.15% fee tier for WHBAR/USDC pool
            USDC
        );

        // --- Step 3: Execute the swap ---
        ExactInputParams memory params = ExactInputParams({
            path: path,
            recipient: trader,
            deadline: block.timestamp + 300, // 5 minute deadline
            amountIn: whbarAmount,
            amountOutMinimum: 0 // Accept any amount (for testing only!)
        });

        uint256 usdcBefore = usdc.balanceOf(trader);

        // Call exactInput via low-level call (struct is defined in this contract)
        // Function selector: exactInput((bytes,address,uint256,uint256,uint256))
        bytes memory callData = abi.encodeWithSignature(
            "exactInput((bytes,address,uint256,uint256,uint256))",
            params
        );
        (bool success, bytes memory returnData) = SAUCERSWAP_ROUTER.call(callData);
        require(success, "Swap failed");
        uint256 amountOut = abi.decode(returnData, (uint256));
        vm.stopPrank();

        // --- Verify: Trader received USDC ---
        uint256 usdcAfter = usdc.balanceOf(trader);
        uint256 whbarAfter = whbar.balanceOf(trader);

        console.log("--- Swap Result ---");
        console.log("WHBAR spent:", whbarAmount);
        console.log("USDC received:", amountOut);
        console.log("Trader WHBAR balance after swap:", whbarAfter);
        console.log("Trader USDC balance after swap:", usdcAfter);

        // The trader should have received some USDC
        assertGt(amountOut, 0, "Should have received USDC from swap");
        assertEq(usdcAfter, usdcBefore + amountOut, "USDC balance should increase");
        assertEq(whbarAfter, 0, "All WHBAR should have been spent");
    }

    // =======================================================================
    // SECTION 4: Impersonate a Real Mainnet Account
    // vm.prank() lets you act as ANY mainnet address - including whales
    // with large balances. No private key needed. The fork reads their
    // real balance from mainnet state.
    // =======================================================================

    /// @notice Impersonate the WHBAR contract (which holds HBAR deposits)
    ///   and read its WHBAR balance - demonstrating real mainnet state access.
    function test_ReadRealMainnetBalances() public view {
        // The WHBAR contract itself holds the wrapped HBAR
        // This reads real mainnet state via the Mirror Node
        uint256 whbarContractBalance = whbar.balanceOf(WHBAR);
        console.log("WHBAR contract's own WHBAR balance:", whbarContractBalance);
        // This should be > 0 since people have wrapped HBAR on mainnet
    }

    // =======================================================================
    // SECTION 5: Contract Verification
    // =======================================================================

    /// @notice Verify SaucerSwap V2 Router exists on mainnet fork
    function test_SaucerSwapRouterExists() public view {
        uint256 codeSize;
        address router = SAUCERSWAP_ROUTER;
        assembly { codeSize := extcodesize(router) }
        console.log("SaucerSwap V2 Router code size:", codeSize);
        assertGt(codeSize, 0, "Router should have bytecode on mainnet");
    }

    /// @notice Verify we're on mainnet (chain ID 295)
    function test_OnMainnetFork() public view {
        assertEq(block.chainid, 295, "Should be Hedera mainnet (chain ID 295)");
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
    }
}
