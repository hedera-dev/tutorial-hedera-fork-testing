import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@hashgraph/system-contracts-forking/plugin";

/**
 * Mainnet fork configuration for SaucerSwap and Bonzo Finance tests.
 *
 * Usage:
 *   HARDHAT_CONFIG=hardhat.config.mainnet.ts npx hardhat test test/SaucerSwapForkTest.test.ts
 *   HARDHAT_CONFIG=hardhat.config.mainnet.ts npx hardhat test test/BonzoForkTest.test.ts
 */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.33",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://mainnet.hashio.io/api",
        // @ts-ignore - custom properties for hedera-forking plugin
        chainId: 295,
        // @ts-ignore
        workerPort: 10002,
      },
    },
  },
};

export default config;
