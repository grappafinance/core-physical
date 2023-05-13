// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../mocks/MockERC20.sol";
import "../../mocks/MockWhitelist.sol";

import "../../../core/engines/cross-margin/CrossMarginEngine.sol";
import "../../../core/engines/cross-margin/CrossMarginEngineProxy.sol";
import "../../../core/Pomace.sol";
import "../../../core/PomaceProxy.sol";
import "../../../core/OptionToken.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";

import "../../utils/Utilities.sol";

import {ActionHelper} from "../../shared/ActionHelper.sol";

// solhint-disable max-states-count

/**
 * helper contract for full margin integration test to inherit.
 */
abstract contract CrossMarginFixture is Test, ActionHelper, Utilities {
    CrossMarginEngine internal engine;
    Pomace internal pomace;
    OptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockWhitelist internal whitelist;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint32 internal pidUsdcCollat;

    // eth collateralized call / put
    uint32 internal pidEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1
        vm.label(address(usdc), "USDC");

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2
        vm.label(address(weth), "WETH");

        // predict address of margin account and use it here
        address pomaceAddr = predictAddress(address(this), 6);

        option = new OptionToken(pomaceAddr, address(0)); // nonce: 3
        vm.label(address(option), "OptionToken");

        address pomaceImplementation = address(new Pomace(address(option))); // nonce: 4

        bytes memory pomaceData = abi.encode(Pomace.initialize.selector);

        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, pomaceData))); // 5
        vm.label(address(pomace), "Pomace");

        address engineImplementation = address(new CrossMarginEngine(address(pomace), address(option))); // nonce 6

        bytes memory engineData = abi.encode(CrossMarginEngine.initialize.selector);

        engine = CrossMarginEngine(address(new CrossMarginEngineProxy(engineImplementation, engineData))); // 7
        vm.label(address(engine), "CrossMarginEngine");

        whitelist = new MockWhitelist();
        vm.label(address(whitelist), "Whitelist");

        // register products
        usdcId = pomace.registerAsset(address(usdc));
        wethId = pomace.registerAsset(address(weth));

        engineId = pomace.registerEngine(address(engine));

        pidUsdcCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(usdc));
        pidEthCollat = pomace.getProductId(address(engine), address(weth), address(usdc), address(weth));

        charlie = address(0xcccc);
        vm.label(charlie, "Charlie");

        bob = address(0xb00b);
        vm.label(bob, "Bob");

        alice = address(0xaaaa);
        vm.label(alice, "Alice");

        // make sure timestamp is not 0
        vm.warp(0xffff);

        usdc.mint(alice, 1000_000_000 * 1e6);
        usdc.mint(bob, 1000_000_000 * 1e6);
        usdc.mint(charlie, 1000_000_000 * 1e6);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function mintOptionFor(address _recipient, uint256 _tokenId, uint40 _productId, uint256 _amount) internal {
        address anon = address(0x42424242);

        vm.startPrank(anon);

        uint256 lotOfCollateral = 1_000 * 1e18;

        usdc.mint(anon, lotOfCollateral);
        weth.mint(anon, lotOfCollateral);
        usdc.approve(address(engine), type(uint256).max);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](2);

        uint8 collateralId = uint8(_productId);

        actions[0] = createAddCollateralAction(collateralId, address(anon), lotOfCollateral);
        actions[1] = createMintAction(_tokenId, address(_recipient), _amount);
        engine.execute(address(anon), actions);

        vm.stopPrank();
    }

    // place holder here so forge coverage won't pick it up
    function test() public {}
}
