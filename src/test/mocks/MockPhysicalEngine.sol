// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {IMarginEngine} from "../../../src/interfaces/IMarginEngine.sol";
import {IPhysicalOptionToken} from "../../../src/interfaces/IPhysicalOptionToken.sol";
import {IPomace} from "../../../src/interfaces/IPomace.sol";

import {ActionArgs} from "../../../src/config/types.sol";

/**
 * @title   MockPhysicalEngine
 * @notice  Mock contract to test grappa payout functionality
 */
contract MockPhysicalEngine is IMarginEngine {
    using SafeERC20 for IERC20;

    IPhysicalOptionToken public option;
    IPomace public immutable pomace;

    constructor(address _option, address _pomace) {
        if (_pomace == address(0)) revert();
        if (_option == address(0)) revert();

        pomace = IPomace(_pomace);
        option = IPhysicalOptionToken(_option);
    }

    function setOption(address _option) external {
        option = IPhysicalOptionToken(_option);
    }

    function execute(address _subAccount, ActionArgs[] calldata actions) external {}

    function handleExercise(uint256 _tokenid, uint256 _debtAmount, uint256 _payoutAmount) external {}

    function receiveDebtValue(address _asset, address _sender, uint256 _amount) external {
        _checkIsPomace();

        if (_sender != address(this)) IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
    }

    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) external {
        _checkIsPomace();

        if (_recipient != address(this)) IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    function mintOptionToken(address recipient, uint256 id, uint256 amount) public {
        option.mint(recipient, id, amount);
    }

    function _checkIsPomace() internal view {
        if (msg.sender != address(pomace)) revert("only pomace");
    }
}
