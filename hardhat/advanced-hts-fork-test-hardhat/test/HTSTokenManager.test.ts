import { expect } from "chai";
import { ethers, network } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { HTSTokenManager } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ContractTransactionReceipt } from "ethers";

// HTS Success response code
const SUCCESS = 22n;

describe("HTSTokenManager - HTS Forking Tests", function () {
  // Increase timeout for network operations
  this.timeout(120000);

  // ============================================
  // UPDATE THESE VALUES AFTER RUNNING deploy.ts
  // ============================================
  // Your deployed testnet contract address
  const DEPLOYED_CONTRACT = "0xaaFBdC3b206F6EEd7F3f71fFAb27869C7E46D5e4";
  // The HTS token created during deployment
  const TOKEN_ADDRESS = "0x000000000000000000000000000000000080FDF2";
  // ============================================

  let htsManager: HTSTokenManager;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;

  async function setupFixture(): Promise<{
    htsManager: HTSTokenManager;
    alice: HardhatEthersSigner;
    bob: HardhatEthersSigner;
  }> {
    // Bind to the deployed contract on the forked network
    const contract = await ethers.getContractAt(
      "HTSTokenManager",
      DEPLOYED_CONTRACT
    );

    // Get local test accounts
    const [, aliceSigner, bobSigner] = await ethers.getSigners();

    // Fund local accounts
    await network.provider.send("hardhat_setBalance", [
      aliceSigner.address,
      "0x56BC75E2D63100000" // 100 ETH in hex
    ]);
    await network.provider.send("hardhat_setBalance", [
      bobSigner.address,
      "0x56BC75E2D63100000"
    ]);

    // Fund the contract (it's the treasury and needs gas for operations)
    await network.provider.send("hardhat_setBalance", [
      DEPLOYED_CONTRACT,
      "0x56BC75E2D63100000"
    ]);

    return {
      htsManager: contract as HTSTokenManager,
      alice: aliceSigner,
      bob: bobSigner
    };
  }

  beforeEach(async function () {
    const fixture = await loadFixture(setupFixture);
    htsManager = fixture.htsManager;
    alice = fixture.alice;
    bob = fixture.bob;
  });

  /**
   * Helper function to get response code from receipt
   */
  function getResponseCodeFromReceipt(
    receipt: ContractTransactionReceipt | null
  ): bigint | null {
    const responseEvent = receipt?.logs.find((log: any) => {
      try {
        const parsed = htsManager.interface.parseLog({
          topics: log.topics as string[],
          data: log.data
        });
        return parsed?.name === "ResponseCode";
      } catch {
        return false;
      }
    });

    if (responseEvent) {
      const parsed = htsManager.interface.parseLog({
        topics: responseEvent.topics as string[],
        data: responseEvent.data
      });
      return parsed?.args[0];
    }
    return null;
  }

  /**
   * Helper function to get minted token info from receipt
   */
  function getMintedTokenInfoFromReceipt(
    receipt: any
  ): { newTotalSupply: bigint } | null {
    const mintedEvent = receipt?.logs.find((log: any) => {
      try {
        const parsed = htsManager.interface.parseLog({
          topics: log.topics as string[],
          data: log.data
        });
        return parsed?.name === "MintedToken";
      } catch {
        return false;
      }
    });

    if (mintedEvent) {
      const parsed = htsManager.interface.parseLog({
        topics: mintedEvent.topics as string[],
        data: mintedEvent.data
      });
      return { newTotalSupply: parsed?.args[0] };
    }
    return null;
  }

  /* =========================
      Token Info Tests
     ========================= */

  describe("Token Info", function () {
    it("should get token info for the pre-created token", async function () {
      const tx = await htsManager.getTokenInfoPublic(TOKEN_ADDRESS);
      const receipt = await tx.wait();

      const responseCode = getResponseCodeFromReceipt(receipt);
      expect(responseCode).to.equal(SUCCESS);
      console.log("Successfully retrieved token info");
    });

    it("should get fungible token info for the pre-created token", async function () {
      const tx = await htsManager.getFungibleTokenInfoPublic(TOKEN_ADDRESS);
      const receipt = await tx.wait();

      const infoEvent = receipt?.logs.find((log) => {
        try {
          const parsed = htsManager.interface.parseLog({
            topics: log.topics as string[],
            data: log.data
          });
          return parsed?.name === "FungibleTokenInfo";
        } catch {
          return false;
        }
      });

      expect(infoEvent).to.not.be.undefined;
      console.log("Successfully retrieved fungible token info");
    });

    it("should read token properties via ERC-20 interface", async function () {
      const token = await ethers.getContractAt(
        [
          "function name() view returns (string)",
          "function symbol() view returns (string)",
          "function decimals() view returns (uint8)",
          "function totalSupply() view returns (uint256)",
          "function balanceOf(address) view returns (uint256)"
        ],
        TOKEN_ADDRESS
      );

      const name = await token.name();
      const symbol = await token.symbol();
      const decimals = await token.decimals();
      const totalSupply = await token.totalSupply();

      console.log(`Token Name:  ${name}`);
      console.log(`Token Symbol: ${symbol}`);
      console.log(`Token Decimals: ${decimals}`);
      console.log(`Token Total Supply: ${totalSupply}`);

      expect(name).to.equal("TestForkToken");
      expect(symbol).to.equal("TFT");
    });
  });

  /* =========================
      Token Minting Tests
     ========================= */

  describe("Token Minting", function () {
    it("should mint tokens successfully", async function () {
      const mintAmount = 1000n;

      const tx = await htsManager.mintTokenPublic(
        TOKEN_ADDRESS,
        mintAmount,
        []
      );
      const receipt = await tx.wait();

      const responseCode = getResponseCodeFromReceipt(receipt);
      expect(responseCode).to.equal(SUCCESS);

      const mintInfo = getMintedTokenInfoFromReceipt(receipt);
      expect(mintInfo).to.not.be.null;
      console.log(
        `Minted ${mintAmount} tokens.  New total supply: ${mintInfo?.newTotalSupply}`
      );
    });

    it("should mint tokens multiple times and track total supply", async function () {
      // First mint
      const tx1 = await htsManager.mintTokenPublic(TOKEN_ADDRESS, 500n, []);
      const receipt1 = await tx1.wait();
      const mintInfo1 = getMintedTokenInfoFromReceipt(receipt1);
      console.log(
        `First mint - New total supply: ${mintInfo1?.newTotalSupply}`
      );

      // Second mint
      const tx2 = await htsManager.mintTokenPublic(TOKEN_ADDRESS, 300n, []);
      const receipt2 = await tx2.wait();
      const mintInfo2 = getMintedTokenInfoFromReceipt(receipt2);
      console.log(
        `Second mint - New total supply: ${mintInfo2?.newTotalSupply}`
      );

      // Verify supply increased
      expect(mintInfo2?.newTotalSupply).to.be.gt(
        mintInfo1?.newTotalSupply || 0n
      );
    });

    it("should increase treasury balance after minting", async function () {
      // Get ERC-20 interface
      const token = await ethers.getContractAt(
        ["function balanceOf(address) view returns (uint256)"],
        TOKEN_ADDRESS
      );

      // Check balance before mint
      const balanceBefore = await token.balanceOf(DEPLOYED_CONTRACT);
      console.log(`Treasury balance before mint: ${balanceBefore}`);

      // Mint tokens
      const mintAmount = 2000n;
      const tx = await htsManager.mintTokenPublic(
        TOKEN_ADDRESS,
        mintAmount,
        []
      );
      await tx.wait();

      // Check balance after mint
      const balanceAfter = await token.balanceOf(DEPLOYED_CONTRACT);
      console.log(`Treasury balance after mint: ${balanceAfter}`);

      expect(balanceAfter).to.equal(balanceBefore + mintAmount);
    });
  });

  /* =========================
      Token Transfer Tests
     ========================= */

  describe("Token Transfers", function () {
    it("should transfer tokens from treasury to alice", async function () {
      // First mint some tokens
      const mintAmount = 5000n;
      await htsManager.mintTokenPublic(TOKEN_ADDRESS, mintAmount, []);

      // Get ERC-20 interface
      const token = await ethers.getContractAt(
        ["function balanceOf(address) view returns (uint256)"],
        TOKEN_ADDRESS
      );

      // Check alice's balance before transfer
      const aliceBalanceBefore = await token.balanceOf(alice.address);
      console.log(`Alice balance before transfer:  ${aliceBalanceBefore}`);

      // Transfer tokens from treasury (contract) to alice
      const transferAmount = 1000n;
      const tx = await htsManager.transferTokenPublic(
        TOKEN_ADDRESS,
        DEPLOYED_CONTRACT, // sender (treasury/contract)
        alice.address, // receiver
        transferAmount
      );
      const receipt = await tx.wait();

      const responseCode = getResponseCodeFromReceipt(receipt);
      expect(responseCode).to.equal(SUCCESS);

      // Check alice's balance after transfer
      const aliceBalanceAfter = await token.balanceOf(alice.address);
      console.log(`Alice balance after transfer: ${aliceBalanceAfter}`);

      expect(aliceBalanceAfter).to.equal(aliceBalanceBefore + transferAmount);
    });

    it("should transfer tokens to multiple recipients", async function () {
      // Mint tokens first
      const mintAmount = 10000n;
      await htsManager.mintTokenPublic(TOKEN_ADDRESS, mintAmount, []);

      const token = await ethers.getContractAt(
        ["function balanceOf(address) view returns (uint256)"],
        TOKEN_ADDRESS
      );

      // Transfer to alice
      const aliceAmount = 2000n;
      await htsManager.transferTokenPublic(
        TOKEN_ADDRESS,
        DEPLOYED_CONTRACT,
        alice.address,
        aliceAmount
      );
      console.log(`Transferred ${aliceAmount} to alice`);

      // Transfer to bob
      const bobAmount = 3000n;
      await htsManager.transferTokenPublic(
        TOKEN_ADDRESS,
        DEPLOYED_CONTRACT,
        bob.address,
        bobAmount
      );
      console.log(`Transferred ${bobAmount} to bob`);

      // Verify balances
      const aliceBalance = await token.balanceOf(alice.address);
      const bobBalance = await token.balanceOf(bob.address);

      expect(aliceBalance).to.be.gte(aliceAmount);
      expect(bobBalance).to.be.gte(bobAmount);

      console.log(`Alice final balance: ${aliceBalance}`);
      console.log(`Bob final balance: ${bobBalance}`);
    });

    it("should mint and then transfer in sequence", async function () {
      const token = await ethers.getContractAt(
        [
          "function balanceOf(address) view returns (uint256)",
          "function totalSupply() view returns (uint256)"
        ],
        TOKEN_ADDRESS
      );

      // Get initial state
      const initialSupply = await token.totalSupply();
      console.log(`Initial total supply: ${initialSupply}`);

      // Mint tokens
      const mintAmount = 3000n;
      const mintTx = await htsManager.mintTokenPublic(
        TOKEN_ADDRESS,
        mintAmount,
        []
      );
      await mintTx.wait();
      console.log(`Minted ${mintAmount} tokens`);

      // Verify supply increased
      const supplyAfterMint = await token.totalSupply();
      console.log(`Supply after mint: ${supplyAfterMint}`);
      expect(supplyAfterMint).to.equal(initialSupply + mintAmount);

      // Transfer some tokens
      const transferAmount = 1500n;
      const transferTx = await htsManager.transferTokenPublic(
        TOKEN_ADDRESS,
        DEPLOYED_CONTRACT,
        alice.address,
        transferAmount
      );
      await transferTx.wait();
      console.log(`Transferred ${transferAmount} to alice`);

      // Verify alice received tokens
      const aliceBalance = await token.balanceOf(alice.address);
      expect(aliceBalance).to.be.gte(transferAmount);
      console.log(`Alice balance:  ${aliceBalance}`);

      // Total supply should remain same after transfer
      const supplyAfterTransfer = await token.totalSupply();
      expect(supplyAfterTransfer).to.equal(supplyAfterMint);
    });
  });

  /* =========================
      Token Creation Tests
     ========================= */

  describe("Token Creation", function () {
    it("should create a new token via the contract", async function () {
      const tx = await htsManager.createFungibleTokenPublic(
        "New Test Token",
        "NTT",
        { value: ethers.parseEther("15") }
      );
      const receipt = await tx.wait();

      const createdEvent = receipt?.logs.find((log) => {
        try {
          const parsed = htsManager.interface.parseLog({
            topics: log.topics as string[],
            data: log.data
          });
          return parsed?.name === "CreatedToken";
        } catch {
          return false;
        }
      });

      expect(createdEvent).to.not.be.undefined;

      if (createdEvent) {
        const parsed = htsManager.interface.parseLog({
          topics: createdEvent.topics as string[],
          data: createdEvent.data
        });
        const newTokenAddress = parsed?.args[0];
        console.log(`Created new token at:  ${newTokenAddress}`);
        expect(newTokenAddress).to.not.equal(ethers.ZeroAddress);
      }
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
      const contractCode = await ethers.provider.getCode(DEPLOYED_CONTRACT);
      expect(contractCode).to.not.equal("0x");
      console.log(
        `Contract at ${DEPLOYED_CONTRACT} has ${contractCode.length} bytes of code`
      );
    });

    it("should be able to access the pre-created token", async function () {
      const tokenCode = await ethers.provider.getCode(TOKEN_ADDRESS);
      expect(tokenCode).to.not.equal("0x");
      console.log(`Token at ${TOKEN_ADDRESS} exists on the forked network`);
    });

    it("should verify contract is the token treasury", async function () {
      const token = await ethers.getContractAt(
        ["function balanceOf(address) view returns (uint256)"],
        TOKEN_ADDRESS
      );

      // The contract should be the treasury (where minted tokens go)
      // After we mint, the contract's balance should be > 0
      const mintTx = await htsManager.mintTokenPublic(TOKEN_ADDRESS, 100n, []);
      await mintTx.wait();

      const contractBalance = await token.balanceOf(DEPLOYED_CONTRACT);
      expect(contractBalance).to.be.gt(0n);
      console.log(`Contract (treasury) balance: ${contractBalance}`);
    });
  });
});
