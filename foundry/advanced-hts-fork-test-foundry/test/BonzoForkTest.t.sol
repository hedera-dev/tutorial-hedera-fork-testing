// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/htsSetup.sol";
import {IERC20} from "hedera-forking/IERC20.sol";

// -----------------------------------------------------------------------
// Aave V2 Interfaces (Bonzo uses the same signatures)
// -----------------------------------------------------------------------

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /// @dev Return names say "ETH" because Bonzo forked Aave V2 unchanged,
    ///   but on Hedera these values represent HBAR denominated in 18 decimals.
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralHBAR,
            uint256 totalDebtHBAR,
            uint256 availableBorrowsHBAR,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/// @title BonzoForkTest
/// @notice Real-world fork test: deposit WHBAR and borrow USDC from Bonzo Finance
///   on a forked Hedera mainnet.
/// @dev Bonzo Finance is an Aave V2 fork on Hedera. This test demonstrates:
///
///   1. Giving a test account WHBAR using deal() (no real tokens needed)
///   2. Depositing WHBAR as collateral into Bonzo's LendingPool
///   3. Receiving aWHBAR tokens representing the deposit
///   4. Borrowing USDC against the WHBAR collateral
///   5. Verifying all balances, debt positions, and health factor
///
///   All of this runs against real Bonzo contracts with real liquidity
///   on a fork of Hedera mainnet. No real funds are spent.
///
///   Run with:
///     forge test --match-contract BonzoForkTest \
///       --fork-url https://mainnet.hashio.io/api \
///       -vvv
///
///   Docs: https://docs.bonzo.finance/
///   Contracts: https://docs.bonzo.finance/hub/developer/bonzo-lend/lend-contracts
contract BonzoForkTest is Test {

    // -----------------------------------------------------------------------
    // Bonzo Finance Mainnet Contracts (Aave V2 fork)
    // See: https://docs.bonzo.finance/hub/developer/bonzo-lend/lend-contracts
    // -----------------------------------------------------------------------

    /// @dev Bonzo LendingPool - core deposit/borrow/repay/withdraw contract
    address constant LENDING_POOL = 0x236897c518996163E7b313aD21D1C9fCC7BA1afc;

    // -----------------------------------------------------------------------
    // Token Addresses (Mainnet)
    // -----------------------------------------------------------------------

    /// @dev WHBAR (Wrapped HBAR) - 0.0.1456986, 8 decimals
    address constant WHBAR = 0x0000000000000000000000000000000000163B5a;

    /// @dev USDC (Native Circle-issued) - 0.0.456858, 6 decimals
    address constant USDC = 0x000000000000000000000000000000000006f89a;

    /// @dev aWHBAR - Bonzo interest-bearing WHBAR deposit token
    address constant A_WHBAR = 0x6e96a607F2F5657b39bf58293d1A006f9415aF32;

    /// @dev Variable Debt USDC - Bonzo variable rate borrow debt token
    address constant VARIABLE_DEBT_USDC = 0x8a90C2f80Fc266e204cb37387c69EA2ed42A3cc1;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    IERC20 public whbar;
    IERC20 public usdc;
    IERC20 public aWhbar;
    IERC20 public variableDebtUsdc;
    address public depositor;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------
    function setUp() public {
        // Activate HTS emulation - WHBAR and USDC are HTS tokens
        htsSetup();

        // Bind to real mainnet tokens
        whbar = IERC20(WHBAR);
        usdc = IERC20(USDC);
        aWhbar = IERC20(A_WHBAR);
        variableDebtUsdc = IERC20(VARIABLE_DEBT_USDC);

        // Create a test depositor with HBAR for gas and WHBAR for collateral
        depositor = makeAddr("depositor");
        vm.deal(depositor, 100 ether); // HBAR for gas
    }

    // =======================================================================
    // SECTION 1: Contract and Protocol Verification
    // =======================================================================

    /// @notice Verify the LendingPool has bytecode on the fork
    function test_LendingPoolExists() public view {
        uint256 codeSize;
        address pool = LENDING_POOL;
        assembly { codeSize := extcodesize(pool) }
        console.log("Bonzo LendingPool code size:", codeSize);
        assertGt(codeSize, 0, "LendingPool should have bytecode");
    }

    /// @notice Read real USDC liquidity available in Bonzo on mainnet
    function test_ReadBonzoUSDCLiquidity() public view {
        // USDC held by the aUSDC contract = available liquidity
        uint256 usdcLiquidity = usdc.balanceOf(
            0xB7687538c7f4CAD022d5e97CC778d0b46457c5DB // aUSDC contract
        );
        console.log("Bonzo USDC available liquidity:", usdcLiquidity);
        console.log("Bonzo USDC available (human):", usdcLiquidity / 1e6, "USDC");
        assertGt(usdcLiquidity, 0, "Bonzo should have USDC liquidity");
    }

    // =======================================================================
    // SECTION 2: Deposit WHBAR as Collateral
    // Uses deal() to give the depositor WHBAR, then deposits directly
    // into the LendingPool. The depositor receives aWHBAR tokens.
    // =======================================================================

    /// @notice Deposit WHBAR into Bonzo LendingPool
    function test_DepositWHBAR() public {
        // Give depositor 5000 WHBAR using deal()
        uint256 depositAmount = 5000 * 1e8; // 5000 WHBAR (8 decimals)
        deal(WHBAR, depositor, depositAmount);
        console.log("Depositor WHBAR balance:", whbar.balanceOf(depositor));

        uint256 aWhbarBefore = aWhbar.balanceOf(depositor);

        vm.startPrank(depositor);

        // Approve LendingPool to spend WHBAR
        whbar.approve(LENDING_POOL, depositAmount);

        // Deposit WHBAR as collateral
        ILendingPool(LENDING_POOL).deposit(
            WHBAR,
            depositAmount,
            depositor,  // onBehalfOf
            0           // referralCode
        );

        vm.stopPrank();

        uint256 aWhbarAfter = aWhbar.balanceOf(depositor);
        console.log("aWHBAR received:", aWhbarAfter - aWhbarBefore);

        assertGt(aWhbarAfter, aWhbarBefore, "Should have received aWHBAR tokens");
    }

    // =======================================================================
    // SECTION 3: Full Flow - Deposit WHBAR + Borrow USDC
    // The complete lending/borrowing lifecycle on a forked mainnet:
    // 1. deal() gives the depositor WHBAR (no real tokens needed)
    // 2. Deposit WHBAR as collateral into Bonzo LendingPool
    // 3. Check account data (collateral value, borrowing capacity)
    // 4. Borrow USDC against the WHBAR collateral
    // 5. Verify USDC received and debt token minted
    // =======================================================================

    /// @notice Full flow: deposit WHBAR collateral, then borrow USDC
    function test_DepositWHBARAndBorrowUSDC() public {
        // --- Setup: Give depositor WHBAR via deal() ---
        uint256 depositAmount = 5000 * 1e8; // 5000 WHBAR (8 decimals)
        deal(WHBAR, depositor, depositAmount);

        console.log("=== Step 1: Deposit WHBAR as Collateral ===");
        vm.startPrank(depositor);

        // Approve and deposit
        whbar.approve(LENDING_POOL, depositAmount);
        ILendingPool(LENDING_POOL).deposit(WHBAR, depositAmount, depositor, 0);

        uint256 aWhbarBalance = aWhbar.balanceOf(depositor);
        console.log("aWHBAR balance after deposit:", aWhbarBalance);
        assertGt(aWhbarBalance, 0, "Should have aWHBAR after deposit");

        console.log("=== Step 2: Check Account Data ===");
        // Note: Aave V2 names these "ETH" but on Hedera they represent HBAR values (18 decimals)
        (
            uint256 totalCollateralHBAR,
            uint256 totalDebtHBAR,
            uint256 availableBorrowsHBAR,
            ,
            uint256 ltv,
            uint256 healthFactor
        ) = ILendingPool(LENDING_POOL).getUserAccountData(depositor);

        console.log("Total collateral (HBAR, 18 dec):", totalCollateralHBAR);
        console.log("Total debt (HBAR, 18 dec):", totalDebtHBAR);
        console.log("Available borrows (HBAR, 18 dec):", availableBorrowsHBAR);
        console.log("LTV:", ltv);
        console.log("Health factor:", healthFactor);

        assertGt(totalCollateralHBAR, 0, "Should have collateral after deposit");
        assertGt(availableBorrowsHBAR, 0, "Should have borrowing capacity");

        console.log("=== Step 3: Borrow USDC ===");
        // Borrow a conservative amount of USDC
        uint256 borrowAmount = 10 * 1e6; // 10 USDC (6 decimals)

        uint256 usdcBefore = usdc.balanceOf(depositor);

        ILendingPool(LENDING_POOL).borrow(
            USDC,
            borrowAmount,
            2,          // variable rate
            0,          // referralCode
            depositor
        );

        vm.stopPrank();

        uint256 usdcAfter = usdc.balanceOf(depositor);
        uint256 debtBalance = variableDebtUsdc.balanceOf(depositor);

        console.log("=== Results ===");
        console.log("USDC received:", usdcAfter - usdcBefore);
        console.log("Variable debt USDC:", debtBalance);

        // Verify USDC was received
        assertEq(usdcAfter - usdcBefore, borrowAmount, "Should have received exact borrow amount");

        // Verify debt position
        assertGt(debtBalance, 0, "Should have variable debt after borrow");

        // Check health factor is still healthy
        (, , , , , uint256 hfAfter) = ILendingPool(LENDING_POOL).getUserAccountData(depositor);
        console.log("Health factor after borrow:", hfAfter);
        assertGt(hfAfter, 1e18, "Health factor should be > 1");
    }

    // =======================================================================
    // SECTION 4: Fork Verification
    // =======================================================================

    /// @notice Verify we're on mainnet
    function test_OnMainnetFork() public view {
        assertEq(block.chainid, 295, "Should be Hedera mainnet");
        console.log("Chain ID:", block.chainid);
    }
}
