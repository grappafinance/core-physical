// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../mocks/MockERC20.sol";
import "../../mocks/MockEngine.sol";

import "../../../core/Pomace.sol";
import "../../../core/PomaceProxy.sol";
import "../../../core/OptionToken.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";

import "../../utils/Utilities.sol";

import {ActionHelper} from "../../shared/ActionHelper.sol";

// solhint-disable max-states-count
abstract contract MockedBaseEngineSetup is Test, ActionHelper, Utilities {
    MockEngine internal engine;
    Pomace internal pomace;
    OptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

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

        // predict address of margin account and use it here
        address pomaceAddr = predictAddress(address(this), 6);

        option = new OptionToken(pomaceAddr, address(0)); // nonce: 3

        address pomaceImplementation = address(new Pomace(address(option))); // nonce: 4

        bytes memory data = abi.encode(Pomace.initialize.selector);

        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, data))); // 5

        engine = new MockEngine(address(pomace), address(option)); // nonce 6

        // register products
        usdcId = pomace.registerAsset(address(usdc));
        wethId = pomace.registerAsset(address(weth));

        engineId = pomace.registerEngine(address(engine));

        productId = pomace.getProductId(address(engine), address(weth), address(usdc), address(usdc));
        productIdEthCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(weth));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
