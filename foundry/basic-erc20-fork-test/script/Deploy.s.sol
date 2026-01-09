// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with the account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ERC20Token with deployer as both owner and initial recipient
        ERC20Token token = new ERC20Token(deployer, deployer);

        vm.stopBroadcast();

        console.log("ERC20Token deployed to:", address(token));
        console.log(
            "View on HashScan:  https://hashscan.io/testnet/contract/",
            address(token)
        );
        console.log("");
        console.log("=== IMPORTANT ===");
        console.log("Save this contract address for your fork tests!");
        console.log(
            "Update DEPLOYED_CONTRACT in your test file with this address"
        );
    }
}
