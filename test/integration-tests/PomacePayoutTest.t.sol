// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EngineIntegrationFixture} from "../fixtures/EngineIntegrationFixture.t.sol";

import "../../src/config/types.sol";
import "../../src/config/errors.sol";
import "../../src/config/constants.sol";

/**
 * @dev test getDebtAndPayout function on different token types
 */
contract PomacePayoutTest is EngineIntegrationFixture {
    function testPayoutETHCollatCall() public {
        uint256 tokenId = _mintCallOption(2000 * 1e6, wethCollatProductId, 1 * UNIT);
        vm.warp(expiry);

        (address engine, uint8 debtId, uint256 debt, uint8 payoutId, uint256 payout) =
            pomace.getDebtAndPayout(tokenId, uint64(1 * UNIT));

        assertEq(engine, address(engine));
        assertEq(debtId, usdcId);
        assertEq(debt, 2000 * 1e6);
        assertEq(payoutId, wethId);
        assertEq(payout, 1 * 1e18);
    }

    function testPayoutUSDCollatPut() public {
        uint256 tokenId = _mintPutOption(2000 * 1e6, usdcCollatProductId, 1 * UNIT);

        vm.warp(expiry);

        (address engine, uint8 debtId, uint256 debt, uint8 payoutId, uint256 payout) =
            pomace.getDebtAndPayout(tokenId, uint64(1 * UNIT));

        assertEq(engine, address(engine));
        assertEq(debtId, wethId);
        assertEq(debt, 1 * 1e18);
        assertEq(payoutId, usdcId);
        assertEq(payout, 2000 * 1e6);
    }

    function testCanGetBatchPayout() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = _mintCallOption(1600 * 1e6, wethCollatProductId, 1 * UNIT);
        ids[1] = _mintPutOption(1900 * 1e6, usdcCollatProductId, 1 * UNIT);

        amounts[0] = 1 * UNIT;
        amounts[1] = 1 * UNIT;

        vm.warp(expiry);

        (Balance[] memory debts, Balance[] memory payouts) = pomace.batchGetDebtAndPayouts(ids, amounts);

        assertEq(debts.length, 2);
        assertEq(payouts.length, 2);

        assertEq(debts[0].collateralId, usdcId);
        assertEq(debts[0].amount, 1600 * 1e6);
        assertEq(debts[1].collateralId, wethId);
        assertEq(debts[1].amount, 1 * 1e18);

        assertEq(payouts[0].collateralId, wethId);
        assertEq(payouts[0].amount, 1 * 1e18);
        assertEq(payouts[1].collateralId, usdcId);
        assertEq(payouts[1].amount, 1900 * 1e6);
    }
}
