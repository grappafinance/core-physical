// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../mocks/MockERC20.sol";
import "../../mocks/MockOracle.sol";
import "../../mocks/MockBaseEngine.sol";

import "../../../src/core/Pomace.sol";
import "../../../src/core/PomaceProxy.sol";
import "../../../src/core/PhysicalOptionToken.sol";

import "../../../src/config/enums.sol";
import "../../../src/config/types.sol";

import "../../utils/Utilities.sol";

import {ActionHelper} from "../../shared/ActionHelper.sol";

// solhint-disable max-states-count
abstract contract MockedBaseEngineSetup is Test, ActionHelper, Utilities {
    MockBaseEngine internal engine;
    Pomace internal pomace;
    PhysicalOptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;

    // usdc collateralized call / put
    uint32 internal productId;

    // eth collateralized call / put
    uint32 internal productIdEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1
        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predict address of margin account and use it here
        address pomaceAddr = predictAddress(address(this), 6);

        option = new PhysicalOptionToken(pomaceAddr, address(0)); // nonce: 4

        address pomaceImplementation = address(new Pomace(address(option), address(oracle))); // nonce: 5

        bytes memory data = abi.encodeWithSelector(Pomace.initialize.selector, address(this));

        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, data))); // 6

        engine = new MockBaseEngine(address(pomace), address(option)); // nonce 7

        // register products
        usdcId = pomace.registerAsset(address(usdc));
        wethId = pomace.registerAsset(address(weth));

        engineId = pomace.registerEngine(address(engine));

        productId = pomace.getProductId(address(engine), address(weth), address(usdc), address(usdc));
        productIdEthCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(weth));

        alice = address(0xaaaa);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
