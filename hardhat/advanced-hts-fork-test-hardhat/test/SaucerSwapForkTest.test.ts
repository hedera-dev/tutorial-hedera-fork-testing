import { expect } from "chai";
import { ethers, network } from "hardhat";

// ethers v6 getContractAt returns BaseContract whose connect() also returns BaseContract,
// losing dynamic method access. This local type preserves it through connect() chains.
type DynContract = { [key: string]: any; connect(runner: any): DynContract };

/**
 * SaucerSwap V2 Fork Test - Hedera Mainnet
 *
 * This test forks Hedera mainnet and interacts with live SaucerSwap V2
 * contracts and real HTS tokens (WHBAR, USDC).
 *
 * It demonstrates:
 * 1. Reading real production token metadata (WHBAR, USDC)
 * 2. Executing a real swap through SaucerSwap V2 (WHBAR -> USDC)
 * 3. Verifying swap results against real mainnet liquidity
 *
 * IMPORTANT: To run this test, update your hardhat.config.ts to fork MAINNET:
 *   - url: "https://mainnet.hashio.io/api"
 *   - chainId: 295
 *   - blockNumber: <recent mainnet block>
 *
 * Run with:
 *   npx hardhat test test/SaucerSwapForkTest.test.ts
 *
 * Docs: https://docs.saucerswap.finance/developerx/contract-deployments
 */
describe("SaucerSwap V2 - Mainnet Fork Tests", function () {
  this.timeout(120000);

  // -----------------------------------------------------------------------
  // Mainnet Addresses
  // See: https://docs.saucerswap.finance/developerx/contract-deployments
  // -----------------------------------------------------------------------
  const SAUCERSWAP_ROUTER = "0x00000000000000000000000000000000003c437A"; // 0.0.3949434
  const WHBAR = "0x0000000000000000000000000000000000163B5a"; // 0.0.1456986, 8 decimals
  const USDC = "0x000000000000000000000000000000000006f89a"; // 0.0.456858, 6 decimals

  // Minimal ERC-20 ABI
  const ERC20_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function transfer(address, uint256) returns (bool)",
    "function approve(address, uint256) returns (bool)",
    "function allowance(address, address) view returns (uint256)"
  ];

  // SaucerSwap V2 Router ABI (Uniswap V3 compatible)
  const SWAP_ROUTER_ABI = [
    "function exactInput((bytes path, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum)) external payable returns (uint256 amountOut)"
  ];

  /* =========================
      Token Read Tests
     ========================= */

  describe("Token Metadata", function () {
    it("should read WHBAR metadata from mainnet", async function () {
      const whbar = await ethers.getContractAt(ERC20_ABI, WHBAR) as DynContract;

      const name = await whbar.name();
      const symbol = await whbar.symbol();
      const decimals = await whbar.decimals();
      const totalSupply = await whbar.totalSupply();

      console.log(`WHBAR name: ${name}`);
      console.log(`WHBAR symbol: ${symbol}`);
      console.log(`WHBAR decimals: ${decimals}`);
      console.log(`WHBAR total supply: ${totalSupply}`);

      expect(decimals).to.equal(8);
      expect(totalSupply).to.be.gt(0n);
    });

    it("should read USDC metadata from mainnet", async function () {
      const usdc = await ethers.getContractAt(ERC20_ABI, USDC) as DynContract;

      const name = await usdc.name();
      const symbol = await usdc.symbol();
      const decimals = await usdc.decimals();
      const totalSupply = await usdc.totalSupply();

      console.log(`USDC name: ${name}`);
      console.log(`USDC symbol: ${symbol}`);
      console.log(`USDC decimals: ${decimals}`);
      console.log(`USDC total supply: ${totalSupply}`);

      expect(decimals).to.equal(6);
      expect(totalSupply).to.be.gt(0n);
    });
  });

  /* =========================
      Balance & Transfer Tests
     ========================= */

  describe("Balance and Transfer", function () {
    it("should transfer WHBAR between accounts on the fork", async function () {
      const [, trader, recipient] = await ethers.getSigners();
      const whbar = await ethers.getContractAt(ERC20_ABI, WHBAR) as DynContract;

      // Fund trader with native HBAR for gas
      await network.provider.send("hardhat_setBalance", [
        trader.address,
        "0x56BC75E2D63100000"
      ]);

      // Give trader WHBAR by impersonating Bonzo's aWHBAR (holds real WHBAR deposits)
      const A_WHBAR = "0x6e96a607F2F5657b39bf58293d1A006f9415aF32";
      const amount = 100n * 10n ** 8n; // 100 WHBAR

      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [A_WHBAR]
      });
      await network.provider.send("hardhat_setBalance", [
        A_WHBAR,
        "0x56BC75E2D63100000"
      ]);

      const aWhbarSigner = await ethers.getSigner(A_WHBAR);
      const sourceBalance = await whbar.balanceOf(A_WHBAR);
      console.log(`aWHBAR contract WHBAR balance: ${sourceBalance}`);

      if (sourceBalance < amount) {
        console.log("Insufficient WHBAR, skipping");
        this.skip();
      }

      await whbar.connect(aWhbarSigner).transfer(trader.address, amount);
      await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [A_WHBAR]
      });

      const traderWhbar = await whbar.balanceOf(trader.address);
      console.log(`Trader WHBAR balance after impersonation transfer: ${traderWhbar}`);
      expect(traderWhbar).to.equal(amount);

      // Transfer half to recipient
      await network.provider.send("hardhat_setBalance", [
        recipient.address,
        "0x56BC75E2D63100000"
      ]);
      await whbar.connect(trader).transfer(recipient.address, 50n * 10n ** 8n);

      const traderAfter = await whbar.balanceOf(trader.address);
      const recipientAfter = await whbar.balanceOf(recipient.address);
      console.log(`Trader WHBAR after transfer: ${traderAfter}`);
      console.log(`Recipient WHBAR after transfer: ${recipientAfter}`);
      console.log("WHBAR transfer succeeded on mainnet fork");

      expect(traderAfter).to.equal(50n * 10n ** 8n);
      expect(recipientAfter).to.equal(50n * 10n ** 8n);
    });
  });

  /* =========================
      SaucerSwap Contract Verification
     ========================= */

  describe("SaucerSwap Contract Verification", function () {
    it("should check SaucerSwap V2 Router bytecode", async function () {
      const code = await ethers.provider.getCode(SAUCERSWAP_ROUTER);
      console.log(`SaucerSwap V2 Router code length: ${code.length} bytes`);
      // NOTE: The SaucerSwap Router has a Hedera entity ID-derived address
      // (0x...003c437A). The Hardhat hedera-forking plugin may not fetch
      // bytecode for non-HTS contracts at entity ID addresses. The Foundry
      // fork test handles this correctly. If code is "0x", swap tests will
      // be skipped.
      if (code === "0x") {
        console.log(
          "Router bytecode not available via Hardhat fork - entity ID address limitation"
        );
      }
    });

    it("should verify WHBAR token exists", async function () {
      const code = await ethers.provider.getCode(WHBAR);
      console.log(`WHBAR token code length: ${code.length} bytes`);
      expect(code).to.not.equal("0x");
    });

    it("should verify USDC token exists", async function () {
      const code = await ethers.provider.getCode(USDC);
      console.log(`USDC token code length: ${code.length} bytes`);
      expect(code).to.not.equal("0x");
    });

    it("should be on a forked network", async function () {
      // Hardhat always reports chain ID 31337 locally, even when forking.
      // Verify we're on a fork by checking block number > 0
      const blockNumber = await ethers.provider.getBlockNumber();
      console.log(`Fork block number: ${blockNumber}`);
      expect(blockNumber).to.be.gt(0);
    });
  });

  /* =========================
      Real Swap Test
     ========================= */

  describe("SaucerSwap V2 Swap", function () {
    it("should swap WHBAR for USDC through SaucerSwap V2", async function () {
      // Check if router bytecode is available (entity ID address limitation)
      const routerCode = await ethers.provider.getCode(SAUCERSWAP_ROUTER);
      if (routerCode === "0x") {
        console.log("SaucerSwap Router bytecode not available in Hardhat fork");
        console.log(
          "This is due to the entity ID address format. Use Foundry for this test."
        );
        this.skip();
      }

      const [, trader] = await ethers.getSigners();
      const whbar = await ethers.getContractAt(ERC20_ABI, WHBAR) as DynContract;
      const usdc = await ethers.getContractAt(ERC20_ABI, USDC) as DynContract;
      const router = await ethers.getContractAt(
        SWAP_ROUTER_ABI,
        SAUCERSWAP_ROUTER
      ) as DynContract;

      // Fund trader with native HBAR for gas
      await network.provider.send("hardhat_setBalance", [
        trader.address,
        "0x56BC75E2D63100000"
      ]);

      // Give trader WHBAR by impersonating Bonzo's aWHBAR contract,
      // which holds real WHBAR deposits from Bonzo users on mainnet.
      const A_WHBAR = "0x6e96a607F2F5657b39bf58293d1A006f9415aF32";
      const whbarAmount = 10n * 10n ** 8n; // 10 WHBAR (8 decimals)

      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [A_WHBAR]
      });
      await network.provider.send("hardhat_setBalance", [
        A_WHBAR,
        "0x56BC75E2D63100000"
      ]);

      const aWhbarSigner = await ethers.getSigner(A_WHBAR);
      const aWhbarBal = await whbar.balanceOf(A_WHBAR);
      console.log(`aWHBAR contract WHBAR balance: ${aWhbarBal}`);

      if (aWhbarBal < whbarAmount) {
        console.log("aWHBAR has insufficient WHBAR, skipping swap");
        this.skip();
      }

      await whbar.connect(aWhbarSigner).transfer(trader.address, whbarAmount);
      console.log(`Transferred ${whbarAmount} WHBAR to trader`);

      await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [A_WHBAR]
      });

      // Verify trader has WHBAR
      const traderWhbar = await whbar.balanceOf(trader.address);
      console.log(`Trader WHBAR balance: ${traderWhbar}`);
      expect(traderWhbar).to.be.gte(whbarAmount);

      // Approve router to spend WHBAR
      await whbar.connect(trader).approve(SAUCERSWAP_ROUTER, whbarAmount);
      const allowance = await whbar.allowance(
        trader.address,
        SAUCERSWAP_ROUTER
      );
      console.log(`Router WHBAR allowance: ${allowance}`);

      // Check USDC balance before swap
      const usdcBefore = await usdc.balanceOf(trader.address);
      console.log(`Trader USDC before swap: ${usdcBefore}`);

      // Encode swap path: WHBAR -> 0.15% fee tier (1500) -> USDC
      const path = ethers.solidityPacked(
        ["address", "uint24", "address"],
        [WHBAR, 1500, USDC]
      );

      // Execute swap
      const deadline = Math.floor(Date.now() / 1000) + 300;
      const tx = await router.connect(trader).exactInput({
        path: path,
        recipient: trader.address,
        deadline: deadline,
        amountIn: whbarAmount,
        amountOutMinimum: 0 // Accept any amount (for testing only)
      });
      const receipt = await tx.wait();
      console.log(`Swap tx hash: ${receipt?.hash}`);

      // Check USDC balance after swap
      const usdcAfter = await usdc.balanceOf(trader.address);
      const usdcReceived = usdcAfter - usdcBefore;
      console.log(`Trader USDC after swap: ${usdcAfter}`);
      console.log(`USDC received from swap: ${usdcReceived}`);

      expect(usdcReceived).to.be.gt(0n);
      console.log(
        `Swap result: ${Number(whbarAmount) / 1e8} WHBAR -> ${
          Number(usdcReceived) / 1e6
        } USDC`
      );
    });
  });
});
