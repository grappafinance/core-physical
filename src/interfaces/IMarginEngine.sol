// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ActionArgs, Balance} from "../config/types.sol";

interface IMarginEngine {
    // function getMinCollateral(address _subAccount) external view returns (uint256);

    function execute(address _subAccount, ActionArgs[] calldata actions) external;

    function handleExercise(uint256 _tokenid, uint256 _debtAmount, uint256 _payoutAmount) external;

    function receiveDebtValue(address _asset, address _recipient, uint256 _amount) external;

    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) external;

    /**
     * how the short should be settled
     */
    function getBatchSettlementForShorts(uint256[] calldata _tokenIds, uint256[] calldata _amounts)
        external
        view
        returns (Balance[] memory debts, Balance[] memory payouts);
}
