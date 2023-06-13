// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Pomace} from "../../../src/core/Pomace.sol";
import {PomaceProxy} from "../../../src/core/PomaceProxy.sol";
import {PhysicalOptionToken} from "../../../src/core/PhysicalOptionToken.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";
import {MockPhysicalEngine} from "../mocks/MockPhysicalEngine.sol";

import {Utilities} from "../utils/Utilities.sol";

import {ProductIdUtil} from "../../../src/libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../src/libraries/TokenIdUtil.sol";

import "../../../src/config/errors.sol";
import "../../../src/config/enums.sol";
import "../../../src/config/constants.sol";

/**
 * @notice util contract to setup testing environment
 * @dev this contract setup the Pomace proxy, PhysicalOptionToken, and deploy mocked engine and mocked oracles
 */
abstract contract EngineIntegrationFixture is Test, Utilities {
    Pomace public implementation;
    Pomace public pomace;
    MockERC20 internal weth;
    MockERC20 internal usdc;

    PhysicalOptionToken internal option;

    MockOracle internal oracle;
    MockPhysicalEngine internal engine;

    uint8 internal wethId;
    uint8 internal usdcId;

    uint8 internal engineId;

    uint8 internal oracleId;

    uint32 internal wethCollatProductId;
    uint32 internal usdcCollatProductId;

    uint64 internal expiry;
    uint64 internal expiryWindow;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18); // nonce: 1
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 2

        vm.label(address(weth), "WETH");
        vm.label(address(usdc), "USDC");

        address proxyAddr = predictAddress(address(this), 6);

        option = new PhysicalOptionToken(proxyAddr, address(0)); // nonce: 3
        oracle = new MockOracle();

        implementation = new Pomace(address(option), address(oracle)); // nonce: 4

        bytes memory data = abi.encodeWithSelector(Pomace.initialize.selector, address(this));
        pomace = Pomace(address(new PomaceProxy(address(implementation), data))); // nonce: 5

        assertEq(proxyAddr, address(pomace));

        wethId = pomace.registerAsset(address(weth));
        usdcId = pomace.registerAsset(address(usdc));

        // use mocked engine and oracle

        engine = new MockPhysicalEngine(address(option), address(pomace));
        engineId = pomace.registerEngine(address(engine));

        pomace.setCollateralizable(address(weth), address(usdc), true);
        pomace.setCollateralizable(address(usdc), address(weth), true);

        wethCollatProductId = ProductIdUtil.getProductId(engineId, wethId, usdcId, wethId);
        usdcCollatProductId = ProductIdUtil.getProductId(engineId, wethId, usdcId, usdcId);

        expiry = uint64(block.timestamp + 14 days);
        expiryWindow = uint64(30 minutes);

        // give mock engine lots of eth and usdc so it can pay out
        weth.mint(address(engine), 1_000_000 * 1e18);
        usdc.mint(address(engine), 1_000_000 * 1e6);

        oracle.setSpotPrice(address(usdc), 1 * 1e6);
        oracle.setSpotPrice(address(weth), 2000 * 1e6);
    }

    function _mintCallOption(uint64 strike, uint32 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, strike, expiryWindow);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function _mintPutOption(uint64 strike, uint32 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.PUT, productId, expiry, strike, expiryWindow);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
