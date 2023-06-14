// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProductIdUtil} from "../../src/libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../src/libraries/TokenIdUtil.sol";

import {EngineIntegrationFixture} from "../fixtures/EngineIntegrationFixture.t.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import "../../src/config/types.sol";
import "../../src/config/errors.sol";
import "../../src/config/constants.sol";

/**
 * @dev test getPayout function on different token types
 */
contract PomaceSettlementTest is EngineIntegrationFixture {
    uint256 internal engineUsdcBefore;
    uint256 internal engineWethBefore;
    uint256 internal selfUsdcBefore;
    uint256 internal selfWethBefore;

    constructor() EngineIntegrationFixture() {
        usdc.mint(address(this), 1_000_000 * 1e6);
        usdc.approve(address(engine), 1_000_000 * 1e6);
    }

    function setUp() public {
        engineUsdcBefore = usdc.balanceOf(address(engine));
        selfUsdcBefore = usdc.balanceOf(address(this));

        engineWethBefore = weth.balanceOf(address(engine));
        selfWethBefore = weth.balanceOf(address(this));
    }

    function testSettleETHCollatCall() public {
        uint256 tokenId = _mintCallOption(2000 * 1e6, wethCollatProductId, 1 * UNIT);

        vm.warp(expiry);

        pomace.settleOption(address(this), tokenId, 1 * UNIT);

        assertEq(weth.balanceOf(address(this)), 1 * 1e18);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore - 1 * 1e18);

        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore - 2000 * 1e6);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore + 2000 * 1e6);
    }

    function testSettleUSDCollatPut() public {
        weth.mint(address(this), 1 * 1e18);
        weth.approve(address(engine), 1 * 1e18);

        uint256 tokenId = _mintPutOption(2000 * 1e6, usdcCollatProductId, 1e6);

        vm.warp(expiry);

        pomace.settleOption(address(this), tokenId, 1 * UNIT);

        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore + 1 * 1e18);

        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore + 2000 * 1e6);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore - 2000 * 1e6);
    }

    function testBatchSettleSameCollat() public {
        weth.approve(address(engine), 1 * 1e18);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = _mintCallOption(2000 * 1e6, wethCollatProductId, 1 * UNIT);
        ids[1] = _mintCallOption(2500 * 1e6, wethCollatProductId, 1 * UNIT);

        amounts[0] = 1 * UNIT;
        amounts[1] = 1 * UNIT;

        vm.warp(expiry);

        pomace.batchSettleOptions(address(this), ids, amounts);

        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore - 4500 * 1e6);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore + 4500 * 1e6);

        assertEq(weth.balanceOf(address(this)), 2 * 1e18);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore - 2 * 1e18);
    }

    function testSettleDiffCollat() public {
        weth.approve(address(engine), 1 * 1e18);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = _mintCallOption(1600 * 1e6, wethCollatProductId, 1 * UNIT);
        ids[1] = _mintPutOption(1900 * 1e6, usdcCollatProductId, 1 * UNIT);

        amounts[0] = 1 * UNIT;
        amounts[1] = 1 * UNIT;

        vm.warp(expiry);

        pomace.batchSettleOptions(address(this), ids, amounts);

        // receive 1900 usd payout to self (put option) and send 1600 debt (call option) (1900 - 16000 = 300)
        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore + 300 * 1e6);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore - 300 * 1e6);

        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore);
    }

    function testSettleWithNonUnderlyingNorStrike() public {
        weth.mint(address(this), 1 * 1e18);
        weth.approve(address(engine), 1 * 1e18);

        // eth put collateralized in btc
        MockERC20 wbtc = new MockERC20("WBTC", "WBTC", 8);
        wbtc.mint(address(engine), 100 * 1e8);

        uint8 wbtcId = pomace.registerAsset(address(wbtc));

        pomace.setCollateralizable(address(usdc), address(wbtc), true);

        uint32 productId = ProductIdUtil.getProductId(engineId, wethId, usdcId, wbtcId);
        uint256 tokenId = _mintPutOption(2000 * 1e6, productId, 1 * UNIT);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 1600 * 1e6);
        oracle.setExpiryPrice(address(wbtc), address(usdc), 16000 * 1e6);

        pomace.settleOption(address(this), tokenId, 1 * UNIT);

        assertEq(wbtc.balanceOf(address(this)), 0.125 * 1e8);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore);

        uint256 expectedEngineWbtcBalance = 100 * 1e8 - 0.125 * 1e8;

        assertEq(wbtc.balanceOf(address(engine)), expectedEngineWbtcBalance);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore + 1 * 1e18);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore);
    }

    function testCannotPassInInconsistentArray() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(PM_WrongArgumentLength.selector);
        pomace.batchSettleOptions(address(this), ids, amounts);
    }

    function testCannotMintExpiredOption() public {
        uint256 tokenId =
            TokenIdUtil.getTokenId(TokenType.CALL, usdcCollatProductId, uint64(block.timestamp - 1), uint64(1 * UNIT), 30 minutes);

        vm.expectRevert(PM_InvalidExpiry.selector);
        engine.mintOptionToken(address(this), tokenId, 1 * UNIT);
    }

    function testCannotMintOptionZeroExerciseWindow() public {
        uint256 tokenId =
            TokenIdUtil.getTokenId(TokenType.CALL, usdcCollatProductId, uint64(block.timestamp - 1), uint64(1 * UNIT), 0);

        vm.expectRevert(PM_InvalidExerciseWindow.selector);
        engine.mintOptionToken(address(this), tokenId, 1 * UNIT);
    }
}
