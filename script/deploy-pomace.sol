// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/core/Pomace.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);
        console.log("Deployer", msg.sender);

        console.log("\n---- START ----");

        address pomace = address(new Pomace(vm.envAddress("OptionToken"), vm.envAddress("ChainlinkOracleDisputable")));

        console.log("pomace \t\t\t", pomace);

        vm.stopBroadcast();
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
