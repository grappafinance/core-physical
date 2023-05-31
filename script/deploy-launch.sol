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

import "../src/core/oracles/ChainlinkOracle.sol";
import "../src/core/oracles/ChainlinkOracleDisputable.sol";

import "../src/test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        // deploy and register Oracles
        // (, address clOracleDisputable) = deployOracles();
        address clOracleDisputable = vm.envAddress("OracleOwner");

        // Deploy core components
        deployCore(clOracleDisputable);

        // Todo: transfer ownership to Pomace multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    function deployOracles() public returns (address clOracle, address clOracleDisputable) {
        // ============ Deploy Chainlink Oracles ============== //
        clOracle = address(new ChainlinkOracle(vm.envAddress("OracleOwner")));
        clOracleDisputable = address(new ChainlinkOracleDisputable(vm.envAddress("OracleOwner")));
    }

    /// @dev deploy core contracts: Upgradable Pomace, non-upgradable OptionToken with descriptor
    function deployCore(address oracle) public returns (Pomace pomace, address optionDescriptor, address optionToken) {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);
        console.log("Deployer", msg.sender);

        console.log("\n---- START ----");

        // =================== Deploy Pomace (Upgradable) =============== //
        address optionTokenAddr = predictAddress(msg.sender, nonce + 4);

        address implementation = address(new Pomace(optionTokenAddr, oracle)); // nonce
        console.log("pomace implementation\t\t", address(implementation));
        bytes memory data = abi.encodeWithSelector(Pomace.initialize.selector, vm.envAddress("PomaceOwner"));
        pomace = Pomace(address(new PomaceProxy(implementation, data))); // nonce + 1

        console.log("pomace proxy \t\t\t", address(pomace));

        // =================== Deploy Option Descriptor (Upgradable) =============== //

        address descriptorImpl = address(new OptionTokenDescriptor()); // nonce + 2
        bytes memory descriptorInitData = abi.encode(OptionTokenDescriptor.initialize.selector);
        optionDescriptor = address(new ERC1967Proxy(descriptorImpl, descriptorInitData)); // nonce + 3
        console.log("optionToken descriptor\t", optionDescriptor);

        // =============== Deploy OptionToken ================= //

        optionToken = address(new OptionToken(address(pomace), optionDescriptor)); // nonce + 4
        console.log("optionToken\t\t\t", optionToken);

        // revert if deployed contract is different than what we set in Pomace
        assert(address(optionToken) == optionTokenAddr);

        console.log("\n---- Core deployment ended ----\n");
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testChill() public {}
}
