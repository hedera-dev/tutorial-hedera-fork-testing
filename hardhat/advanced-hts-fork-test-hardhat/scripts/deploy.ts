import { ethers } from "hardhat";

async function main(): Promise<void> {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "HBAR");

  // 1) Deploy the HTSTokenManager contract
  // Hedera's JSON-RPC relay can fail on eth_estimateGas with INSUFFICIENT_TX_FEE,
  // so we provide explicit gas settings to bypass estimation.
  console.log("\n--- Deploying HTSTokenManager ---");
  const HTSTokenManager = await ethers.getContractFactory("HTSTokenManager");
  const htsManager = await HTSTokenManager.deploy({
    gasLimit: 3_000_000,
    gasPrice: ethers.parseUnits("1100", "gwei")
  });
  await htsManager.waitForDeployment();

  const contractAddress = await htsManager.getAddress();
  console.log("HTSTokenManager deployed to:", contractAddress);
  console.log(
    "View on HashScan: https://hashscan.io/testnet/contract/" + contractAddress
  );

  // 2) Create a fungible token using the contract
  console.log("\n--- Creating HTS Fungible Token ---");
  const TOKEN_NAME = "TestForkToken";
  const TOKEN_SYMBOL = "TFT";
  const HBAR_TO_SEND = "15"; // HBAR to send for token creation

  console.log(`Creating token "${TOKEN_NAME}" (${TOKEN_SYMBOL})...`);
  console.log(`Sending ${HBAR_TO_SEND} HBAR for token creation...`);

  const createTx = await htsManager.createFungibleTokenPublic(
    TOKEN_NAME,
    TOKEN_SYMBOL,
    {
      gasLimit: 1_000_000,
      value: ethers.parseEther(HBAR_TO_SEND)
    }
  );
  const createReceipt = await createTx.wait();
  console.log("createFungibleTokenPublic() tx hash:", createTx.hash);

  // 3) Extract token address from CreatedToken event
  let tokenAddress: string | null = null;
  for (const log of createReceipt?.logs || []) {
    try {
      const parsed = htsManager.interface.parseLog({
        topics: log.topics as string[],
        data: log.data
      });
      if (parsed?.name === "CreatedToken") {
        tokenAddress = parsed.args[0];
        break;
      }
    } catch {
      // Not our event, skip
    }
  }

  if (!tokenAddress) {
    throw new Error("Failed to extract token address from CreatedToken event");
  }

  console.log("HTS Token created at:", tokenAddress);
  console.log(
    "View token on HashScan: https://hashscan.io/testnet/token/" + tokenAddress
  );

  // 4) Get deployment block number
  const blockNumber = await ethers.provider.getBlockNumber();
  console.log("\nDeployed at block number:", blockNumber);

  // 5) Summary
  console.log("\n" + "=".repeat(60));
  console.log("DEPLOYMENT SUMMARY");
  console.log("=".repeat(60));
  console.log("HTSTokenManager Contract:", contractAddress);
  console.log("HTS Token Address:        ", tokenAddress);
  console.log("Block Number:            ", blockNumber);
  console.log("=".repeat(60));
  console.log("\n=== IMPORTANT ===");
  console.log("Update your hardhat.config.ts with:");
  console.log(`  blockNumber: ${blockNumber}`);
  console.log("\nUpdate your test file with:");
  console.log(`  DEPLOYED_CONTRACT = "${contractAddress}"`);
  console.log(`  TOKEN_ADDRESS = "${tokenAddress}"`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
