import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@hashgraph/system-contracts-forking/plugin";

// Load configuration variables
const HEDERA_RPC_URL = vars.get("HEDERA_RPC_URL");
const HEDERA_PRIVATE_KEY = vars.get("HEDERA_PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.33",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // Network for deploying to real testnet
    hederaTestnet: {
      url: HEDERA_RPC_URL,
      accounts: [HEDERA_PRIVATE_KEY],
      chainId: 296,
      // Hedera requires explicit gas settings - default estimation often fails
      // with INSUFFICIENT_TX_FEE
      gasPrice: 1_100_000_000_000, // 1100 gwei - above Hedera's configured minimum
      gas: 3_000_000
    },
    // Local fork of testnet for testing
    hardhat: {
      forking: {
        url: HEDERA_RPC_URL,
        // Pin to a specific block for reproducible tests
        // Update this after deploying your contract
        blockNumber: 33462232,
        // @ts-ignore - custom properties for hedera-forking plugin
        chainId: 296,
        // @ts-ignore
        workerPort: 10001
      }
    }
  }
};

export default config;
