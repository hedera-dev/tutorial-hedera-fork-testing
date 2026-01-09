import { expect } from "chai";
import { ethers, network } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ERC20Token } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("ERC20Token - Forked Network Tests", function () {
  // Your deployed testnet contract:
  // https://hashscan.io/testnet/contract/0xea606E2D68Ff9F211756b8cfd9026a7Eb76845C9
  const DEPLOYED_CONTRACT = "0xea606E2D68Ff9F211756b8cfd9026a7Eb76845C9"; // Update with your deployed address

  let token: ERC20Token;
  let realOwner: HardhatEthersSigner;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;

  /**
   * Fixture to set up the test environment.
   * Using fixtures ensures each test starts with a clean state.
   */
  async function setupFixture(): Promise<{
    token: ERC20Token;
    realOwner: HardhatEthersSigner;
    ownerAddress: string;
    alice: HardhatEthersSigner;
    bob: HardhatEthersSigner;
  }> {
    // Bind to the deployed contract on the forked network
    const tokenContract = await ethers.getContractAt(
      "ERC20Token",
      DEPLOYED_CONTRACT
    );

    // Discover the real on-chain owner (from Ownable)
    const ownerAddress = await tokenContract.owner();

    // Impersonate the real owner so we can call onlyOwner functions
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ownerAddress]
    });
    const impersonatedOwner = await ethers.getSigner(ownerAddress);

    // Fund the impersonated account with ETH for gas
    await network.provider.send("hardhat_setBalance", [
      ownerAddress,
      "0x56BC75E2D63100000" // 100 ETH in hex
    ]);

    // Get local test accounts for recipients
    const [, aliceSigner, bobSigner] = await ethers.getSigners();

    // Fund local accounts
    await network.provider.send("hardhat_setBalance", [
      aliceSigner.address,
      "0x56BC75E2D63100000"
    ]);
    await network.provider.send("hardhat_setBalance", [
      bobSigner.address,
      "0x56BC75E2D63100000"
    ]);

    return {
      token: tokenContract as ERC20Token,
      realOwner: impersonatedOwner,
      ownerAddress,
      alice: aliceSigner,
      bob: bobSigner
    };
  }

  beforeEach(async function () {
    const fixture = await loadFixture(setupFixture);
    token = fixture.token;
    realOwner = fixture.realOwner;
    alice = fixture.alice;
    bob = fixture.bob;
  });

  /* =========================
          Basic Info
     ========================= */

  describe("Token Information (Reading from Forked State)", function () {
    it("should read name and symbol from deployed contract", async function () {
      expect(await token.name()).to.equal("MyToken");
      expect(await token.symbol()).to.equal("MTK");
    });

    it("should read decimals from deployed contract", async function () {
      expect(await token.decimals()).to.equal(18n);
    });

    it("should read total supply from deployed contract", async function () {
      const totalSupply = await token.totalSupply();
      console.log(
        `Total supply on testnet: ${ethers.formatEther(totalSupply)} MTK`
      );
      expect(totalSupply).to.be.gt(0n);
    });

    it("should read owner balance from deployed contract", async function () {
      const ownerAddress = await token.owner();
      const balance = await token.balanceOf(ownerAddress);
      console.log(
        `Owner (${ownerAddress}) balance: ${ethers.formatEther(balance)} MTK`
      );
      expect(balance).to.be.gt(0n);
    });
  });

  /* =========================
          Ownership
     ========================= */

  describe("Ownership (Testing with Impersonation)", function () {
    it("should reject minting from non-owner", async function () {
      // Alice (not the owner) tries to mint → should revert
      await expect(
        token.connect(alice).mint(alice.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });

    it("should allow real owner to mint new tokens", async function () {
      const balanceBefore = await token.balanceOf(alice.address);

      // Use the impersonated real owner to mint
      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("500"));

      const balanceAfter = await token.balanceOf(alice.address);
      expect(balanceAfter).to.equal(balanceBefore + ethers.parseEther("500"));
    });
  });

  /* =========================
          Transfers
     ========================= */

  describe("Transfers (Modifying Forked State)", function () {
    it("should transfer tokens from owner to alice", async function () {
      const amount = ethers.parseEther("100");
      const balanceBefore = await token.balanceOf(alice.address);

      // Transfer from impersonated owner
      await token.connect(realOwner).transfer(alice.address, amount);

      const balanceAfter = await token.balanceOf(alice.address);
      expect(balanceAfter).to.equal(balanceBefore + amount);
    });

    it("should handle multiple transfers correctly", async function () {
      // Mint tokens to alice first
      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("1000"));

      const aliceInitial = await token.balanceOf(alice.address);
      const bobInitial = await token.balanceOf(bob.address);

      // Alice transfers to bob
      await token
        .connect(alice)
        .transfer(bob.address, ethers.parseEther("300"));

      expect(await token.balanceOf(alice.address)).to.equal(
        aliceInitial - ethers.parseEther("300")
      );
      expect(await token.balanceOf(bob.address)).to.equal(
        bobInitial + ethers.parseEther("300")
      );
    });

    it("should fail transfer with insufficient balance", async function () {
      // Bob has no tokens initially, should fail
      await expect(
        token.connect(bob).transfer(alice.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });
  });

  /* =========================
        Allowances
     ========================= */

  describe("Allowances", function () {
    it("should approve and check allowance", async function () {
      // Mint tokens to alice
      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("1000"));

      // Alice approves bob
      await token.connect(alice).approve(bob.address, ethers.parseEther("500"));

      expect(await token.allowance(alice.address, bob.address)).to.equal(
        ethers.parseEther("500")
      );
    });

    it("should transfer using transferFrom after approval", async function () {
      // Mint tokens to alice
      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("1000"));

      // Alice approves bob
      await token.connect(alice).approve(bob.address, ethers.parseEther("500"));

      const aliceBefore = await token.balanceOf(alice.address);

      // Bob transfers from alice to himself
      await token
        .connect(bob)
        .transferFrom(alice.address, bob.address, ethers.parseEther("200"));

      expect(await token.balanceOf(bob.address)).to.equal(
        ethers.parseEther("200")
      );
      expect(await token.balanceOf(alice.address)).to.equal(
        aliceBefore - ethers.parseEther("200")
      );
      expect(await token.allowance(alice.address, bob.address)).to.equal(
        ethers.parseEther("300")
      );
    });

    it("should fail transferFrom without approval", async function () {
      // Mint tokens to alice but no approval for bob
      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("1000"));

      await expect(
        token
          .connect(bob)
          .transferFrom(alice.address, bob.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "ERC20InsufficientAllowance");
    });
  });

  /* =========================
       Supply Changes
     ========================= */

  describe("Supply Changes", function () {
    it("should track supply changes after minting", async function () {
      const supplyBefore = await token.totalSupply();

      await token
        .connect(realOwner)
        .mint(alice.address, ethers.parseEther("5000"));

      const supplyAfter = await token.totalSupply();
      expect(supplyAfter).to.equal(supplyBefore + ethers.parseEther("5000"));
    });
  });

  /* =========================
      Fork Verification
     ========================= */

  describe("Fork Network Verification", function () {
    it("should be connected to a forked network", async function () {
      const blockNumber = await ethers.provider.getBlockNumber();
      console.log(`Current fork block number: ${blockNumber}`);
      expect(blockNumber).to.be.gt(0);
    });

    it("should be interacting with real deployed contract", async function () {
      // Verify we're reading from the actual deployed contract
      const contractCode = await ethers.provider.getCode(DEPLOYED_CONTRACT);
      expect(contractCode).to.not.equal("0x");
      console.log(
        `Contract at ${DEPLOYED_CONTRACT} has ${contractCode.length} bytes of code`
      );
    });

    it("should preserve original state for each test (via fixtures)", async function () {
      // Each test starts fresh because of loadFixture's snapshot/revert
      const ownerAddress = await token.owner();
      const originalBalance = await token.balanceOf(ownerAddress);

      // This change only affects this test
      await token
        .connect(realOwner)
        .transfer(alice.address, ethers.parseEther("100"));

      // In the next test, the balance will be back to original
      console.log(
        `Original owner balance:  ${ethers.formatEther(originalBalance)} MTK`
      );
    });
  });
});