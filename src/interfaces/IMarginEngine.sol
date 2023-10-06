// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarginEngine {
    function handleExercise(uint256 _tokenid, uint256 _debtAmount, uint256 _payoutAmount) external;

    function receiveDebtValue(address _asset, address _recipient, uint256 _amount) external;

    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) external;
}
