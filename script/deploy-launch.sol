// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/core/OptionToken.sol";
import "../src/core/OptionTokenDescriptor.sol";
import "../src/core/Pomace.sol";
import "../src/core/PomaceProxy.sol";
import "../src/core/engines/cross-margin/CrossMarginEngine.sol";
import "../src/core/engines/cross-margin/CrossMarginEngineProxy.sol";

import "../src/test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        // Deploy core components
        (Pomace pomace,, address optionToken) = deployCore();

        // deploy and register Cross Margin Engine
        deployCrossMarginEngine(pomace, optionToken);

        // Todo: transfer ownership to Pomace multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    /// @dev deploy core contracts: Upgradable Pomace, non-upgradable OptionToken with descriptor
    function deployCore() public returns (Pomace pomace, address optionDesciptor, address optionToken) {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);
        console.log("Deployer", msg.sender);

        console.log("\n---- START ----");

        // =================== Deploy Pomace (Upgradable) =============== //
        address optionTokenAddr = predictAddress(msg.sender, nonce + 4);

        address implementation = address(new Pomace(optionTokenAddr)); // nonce
        console.log("pomace implementation\t\t", address(implementation));
        bytes memory data = abi.encode(Pomace.initialize.selector);
        pomace = Pomace(address(new PomaceProxy(implementation, data))); // nonce + 1

        console.log("pomace proxy \t\t\t", address(pomace));

        // =================== Deploy Option Desciptor (Upgradable) =============== //

        address descriptorImpl = address(new OptionTokenDescriptor()); // nonce + 2
        bytes memory descriptorInitData = abi.encode(OptionTokenDescriptor.initialize.selector);
        optionDesciptor = address(new ERC1967Proxy(descriptorImpl, descriptorInitData)); // nonce + 3
        console.log("optionToken descriptor\t", optionDesciptor);

        // =============== Deploy OptionToken ================= //

        optionToken = address(new OptionToken(address(pomace), optionDesciptor)); // nonce + 4
        console.log("optionToken\t\t\t", optionToken);

        // revert if deployed contract is different than what we set in Pomace
        assert(address(optionToken) == optionTokenAddr);

        console.log("\n---- Core deployment ended ----\n");
    }

    function deployCrossMarginEngine(Pomace pomace, address optionToken) public returns (address crossMarginEngine) {
        // ============ Deploy Cross Margin Engine (Upgradable) ============== //
        address engineImplementation = address(new CrossMarginEngine(address(pomace), optionToken));
        bytes memory engineData = abi.encode(CrossMarginEngine.initialize.selector);
        crossMarginEngine = address(new CrossMarginEngineProxy(engineImplementation, engineData));

        console.log("CrossMargin Engine: \t\t", crossMarginEngine);

        // ============ Register Full Margin Engine ============== //
        {
            uint256 engineId = pomace.registerEngine(crossMarginEngine);
            console.log("   -> Registered ID:", engineId);
        }
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
