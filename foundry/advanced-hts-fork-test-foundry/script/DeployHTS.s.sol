// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {HTSTokenManager} from "../src/HTSTokenManager.sol";

/// @title DeployHTSScript
/// @notice Deploys HTSTokenManager to Hedera testnet.
/// @dev This script ONLY deploys the contract. HTS token creation must be done
///   separately using `cast send` because forge script simulates locally first,
///   and the HTS precompile at 0x167 has no EVM bytecode to simulate against.
///
///   Step 1 - Deploy the contract:
///     source .env
///     forge script script/DeployHTS.s.sol:DeployHTSScript \
///       --rpc-url $HEDERA_RPC_URL --broadcast -vvv
///
///   Step 2 - Create the HTS token (see README for the cast send command)
contract DeployHTSScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== HTSTokenManager Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "HBAR");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the HTSTokenManager contract
        HTSTokenManager manager = new HTSTokenManager();

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Successful ===");
        console.log("HTSTokenManager deployed to:", address(manager));
        console.log("Block number:", block.number);
        console.log("View on HashScan: https://hashscan.io/testnet/contract/%s", address(manager));
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Export the contract address:");
        console.log("   export CONTRACT_ADDRESS=<address above>");
        console.log("");
        console.log("2. Create the HTS token:");
        console.log("   cast send $CONTRACT_ADDRESS 'createFungibleTokenPublic(string,string)' 'DemoHTS' 'DHTS' --value 15ether --rpc-url $HEDERA_RPC_URL --private-key $HEDERA_PRIVATE_KEY");
        console.log("");
        console.log("3. Get the token address:");
        console.log("   cast abi-decode 'tokenAddress()(address)' $(cast call $CONTRACT_ADDRESS 'tokenAddress()' --rpc-url $HEDERA_RPC_URL)");
    }
}
