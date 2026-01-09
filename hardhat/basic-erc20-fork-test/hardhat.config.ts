import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@hashgraph/system-contracts-forking/plugin";

// Load configuration variables
const HEDERA_RPC_URL = vars.get("HEDERA_RPC_URL");
const HEDERA_PRIVATE_KEY = vars.get("HEDERA_PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: "0.8.33",
  networks: {
    // Network for deploying to real testnet
    hederaTestnet: {
      url: HEDERA_RPC_URL,
      accounts: [HEDERA_PRIVATE_KEY],
      chainId: 296
    },
    // Local fork of testnet for testing
    hardhat: {
      forking: {
        url: HEDERA_RPC_URL,
        // Pin to a specific block for reproducible tests
        // Update this after deploying your contract
        blockNumber: 29965248,
        // @ts-ignore - custom properties for hedera-forking plugin
        chainId: 296,
        // @ts-ignore
        workerPort: 10001
      }
    }
  }
};

export default config;
