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

    function testSettlePutWithNonUnderlyingNorStrike() public {
        weth.mint(address(this), 1 * 1e18);
        weth.approve(address(engine), 1 * 1e18);

        // eth put collateralized in SDYC
        MockERC20 sdyc = new MockERC20("SDYC", "SDYC", 6);

        vm.label(address(sdyc), "SDYC");
        sdyc.mint(address(engine), 10_000 * 1e6);

        uint8 sdycId = pomace.registerAsset(address(sdyc));

        pomace.setCollateralizable(address(usdc), address(sdyc), true);

        // create a product with collateral not same as strike
        uint32 productId = ProductIdUtil.getProductId(engineId, wethId, usdcId, sdycId);
        uint256 tokenId = _mintPutOption(2000 * 1e6, productId, 1 * UNIT);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 1600 * 1e6);
        oracle.setExpiryPrice(address(sdyc), address(usdc), 1.25 * 1e6);

        pomace.settleOption(address(this), tokenId, 1 * UNIT);

        uint256 expectedSdycPayout = 1600 * 1e6;
        uint256 expectedEngineSdycBalance = 10_000 * 1e6 - expectedSdycPayout;

        assertEq(sdyc.balanceOf(address(this)), expectedSdycPayout);
        assertEq(sdyc.balanceOf(address(engine)), expectedEngineSdycBalance);

        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore + 1 * 1e18);

        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore);
    }

    function testSettleCallWithNonUnderlyingNorStrike() public {
        weth.mint(address(this), 1 * 1e18);
        weth.approve(address(engine), 1 * 1e18);

        // eth call collateralized in LsETH
        MockERC20 lsEth = new MockERC20("LsETH", "LsETH", 18);

        vm.label(address(lsEth), "LSETH");
        lsEth.mint(address(engine), 1000 * 1e18);

        uint8 lsEthId = pomace.registerAsset(address(lsEth));

        pomace.setCollateralizable(address(weth), address(lsEth), true);

        // create a product with collateral not same as underlying
        uint32 productId = ProductIdUtil.getProductId(engineId, wethId, usdcId, lsEthId);
        uint256 tokenId = _mintCallOption(2000 * 1e6, productId, 1 * UNIT);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(lsEth), address(weth), 1900 * 1e6);

        pomace.settleOption(address(this), tokenId, 1 * UNIT);

        // 1 UNIT * 1 UNIT / 1900 * 1e6
        uint256 expectedLsEthPayout = 0.000526 * 1e18;
        uint256 expectedEngineLsEthBalance = 1000 * 1e18 - expectedLsEthPayout;

        assertEq(lsEth.balanceOf(address(this)), expectedLsEthPayout);
        assertEq(lsEth.balanceOf(address(engine)), expectedEngineLsEthBalance);

        assertEq(weth.balanceOf(address(this)), 1 * 1e18);
        assertEq(weth.balanceOf(address(engine)), engineWethBefore);

        assertEq(usdc.balanceOf(address(this)), selfUsdcBefore - 2000 * 1e6);
        assertEq(usdc.balanceOf(address(engine)), engineUsdcBefore + 2000 * 1e6);
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
