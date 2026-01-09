import { ethers } from "hardhat";

async function main(): Promise<void> {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "HBAR");

  // Deploy ERC20Token with deployer as both owner and initial recipient
  const ERC20Token = await ethers.getContractFactory("ERC20Token");
  const token = await ERC20Token.deploy(deployer.address, deployer.address);

  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log("ERC20Token deployed to:", tokenAddress);
  console.log(
    "View on HashScan: https://hashscan.io/testnet/contract/" + tokenAddress
  );

  // Get deployment block number for fork testing reference
  const blockNumber = await ethers.provider.getBlockNumber();
  console.log("Deployed at block number:", blockNumber);
  console.log("\n=== IMPORTANT ===");
  console.log("Save this contract address for your fork tests!");
  console.log(
    "Update blockNumber in hardhat. config.ts to >=",
    blockNumber,
    "when forking"
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
