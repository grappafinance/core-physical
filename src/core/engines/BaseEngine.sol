// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable no-empty-blocks

// imported contracts and libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

// interfaces
import {IPomace} from "../../interfaces/IPomace.sol";
import {IPhysicalOptionToken} from "../../interfaces/IPhysicalOptionToken.sol";

// libraries
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

// constants and types
import "../../config/types.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";

/**
 * @title   BaeEngine
 * @author  @antoncoding, @dsshap
 * @dev  common functions / flow that can be shared among MarginEngines
 */
abstract contract BaseEngine {
    using SafeERC20 for IERC20;
    using TokenIdUtil for uint256;

    IPomace public immutable pomace;
    IPhysicalOptionToken public immutable optionToken;

    ///@dev maskedAccount => operator => allowedExecutionLeft
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    ///     allowedExecutionLeft refers to how many times remain that the grantee can update the sub-accounts.
    mapping(uint160 => mapping(address => uint256)) public allowedExecutionLeft;

    /// Events
    event AccountAuthorizationUpdate(uint160 maskId, address account, uint256 updatesAllowed);

    event CollateralAdded(address subAccount, address collateral, uint256 amount);

    event CollateralRemoved(address subAccount, address collateral, uint256 amount);

    event PhysicalOptionTokenMinted(address subAccount, uint256 tokenId, uint256 amount);

    event PhysicalOptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    event PhysicalOptionTokenAdded(address subAccount, uint256 tokenId, uint64 amount);

    event PhysicalOptionTokenRemoved(address subAccount, uint256 tokenId, uint64 amount);

    event ExercisedToken(address subAccount, uint256 tokenId, uint256 amount);

    /// @dev emitted when an account is settled, with array of payouts
    event AccountSettled(address subAccount, Balance[] payouts);

    /// @dev emitted when an account is settled, with single payout
    event AccountSettledSingle(address subAccount, uint8 collateralId, int256 payout);

    /**
     * ========================================================= *
     *                       Constructor
     * ========================================================= *
     */
    constructor(address _pomace, address _optionToken) {
        pomace = IPomace(_pomace);
        optionToken = IPhysicalOptionToken(_optionToken);
    }

    /**
     * ========================================================= *
     *                         External Functions
     * ========================================================= *
     */

    /**
     * @notice  grant or revoke an account access to all your sub-accounts
     * @dev     expected to be call by account owner
     *          usually user should only give access to helper contracts
     * @param   _account account to update authorization
     * @param   _allowedExecutions how many times the account is authorized to update your accounts.
     *          set to max(uint256) to allow permanent access
     */
    function setAccountAccess(address _account, uint256 _allowedExecutions) external {
        uint160 maskedId = uint160(msg.sender) | 0xFF;
        allowedExecutionLeft[maskedId][_account] = _allowedExecutions;

        emit AccountAuthorizationUpdate(maskedId, _account, _allowedExecutions);
    }

    /**
     * @dev resolve access granted to yourself
     * @param _granter address that granted you access
     */
    function revokeSelfAccess(address _granter) external {
        uint160 maskedId = uint160(_granter) | 0xFF;
        allowedExecutionLeft[maskedId][msg.sender] = 0;

        emit AccountAuthorizationUpdate(maskedId, msg.sender, 0);
    }

    /**
     * @dev hook to be invoked by Pomace to handle custom logic of settlement
     */
    function handleExercise(uint256 _tokenId, uint256 _debtPaid, uint256 _amountPaidOut) external virtual {}

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Pomace, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _sender sender of debt
     * @param _amount amount
     */
    function _receiveDebtValue(address _asset, address _sender, uint256 _amount) internal virtual {
        _checkIsPomace();

        if (_sender != address(this)) IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Pomace, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _recipient receiver
     * @param _amount amount
     */
    function _sendPayoutValue(address _asset, address _recipient, uint256 _amount) internal virtual {
        _checkIsPomace();

        if (_recipient != address(this)) IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    // /**
    //  * @notice payout to user on settlement.
    //  * @dev this can only triggered by Pomace, would only be called on settlement.
    //  * @param _asset asset to transfer
    //  * @param _recipient receiver address
    //  * @param _amount amount
    //  */
    // function payCashValue(address _asset, address _recipient, uint256 _amount) public virtual {
    //     if (msg.sender != address(pomace)) revert NoAccess();
    //     if (_recipient != address(this)) IERC20(_asset).safeTransfer(_recipient, _amount);
    // }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * ========================================================= *
     *                Internal Functions For Each Action
     * ========================================================= *
     */

    /**
     * @dev pull token from user, increase collateral in account storage
     *         the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _addCollateralToAccount(_subAccount, collateralId, amount);

        (address collateral,) = pomace.assets(collateralId);

        emit CollateralAdded(_subAccount, collateral, amount);

        // this line will revert if collateral id is not registered.
        IERC20(collateral).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @dev push token to user, decrease collateral in storage
     * @param _data bytes data to decode
     */
    function _removeCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in state
        _removeCollateralFromAccount(_subAccount, collateralId, amount);

        (address collateral,) = pomace.assets(collateralId);

        emit CollateralRemoved(_subAccount, collateral, amount);

        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in storage
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _increaseShortInAccount(_subAccount, tokenId, amount);

        emit PhysicalOptionTokenMinted(_subAccount, tokenId, amount);

        // mint option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in storage
     *         the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _decreaseShortInAccount(_subAccount, tokenId, amount);

        emit PhysicalOptionTokenBurned(_subAccount, tokenId, amount);

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev Add long token into the account to reduce capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _addOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, uint64 amount, address from) = abi.decode(_data, (uint256, uint64, address));

        // token being added must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        _verifyLongTokenIdToAdd(tokenId);

        // update the state
        _increaseLongInAccount(_subAccount, tokenId, amount);

        emit PhysicalOptionTokenAdded(_subAccount, tokenId, amount);

        // transfer the option token in
        IERC1155(address(optionToken)).safeTransferFrom(from, address(this), tokenId, amount, "");
    }

    /**
     * @dev Remove long token from the account to increase capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _removeOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, uint64 amount, address to) = abi.decode(_data, (uint256, uint64, address));

        // update the state
        _decreaseLongInAccount(_subAccount, tokenId, amount);

        emit PhysicalOptionTokenRemoved(_subAccount, tokenId, amount);

        // transfer the option token out
        IERC1155(address(optionToken)).safeTransferFrom(address(this), to, tokenId, amount, "");
    }

    /**
     * @notice  exercises a long token in margin account at expiry but before settlement window
     * @dev     this updates the account storage
     */
    function _exerciseToken(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, uint64 amount) = abi.decode(_data, (uint256, uint64));

        _exerciseTokenInAccount(_subAccount, tokenId, amount);

        emit ExercisedToken(_subAccount, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account storage
     */
    function _settle(address _subAccount) internal virtual {
        // if payout is positive, the "option token" this account minted worth something
        // so some collateral should be subtracted from the account.
        // payout can be negative because the account could have spread positions that has positive PNL at the end
        // for example if the account short a 1000-1100 call spread, and the price is 1050
        // the account should earn $50 at expiry
        (uint8 collateralId, int80 payout) = _getAccountPayout(_subAccount);

        // update the account in state
        _settleAccount(_subAccount, payout);

        emit AccountSettledSingle(_subAccount, collateralId, payout);
    }

    /**
     * ========================================================= *
     *                State changing functions to override
     * ========================================================= *
     */
    function _addCollateralToAccount(address _subAccount, uint8 collateralId, uint80 amount) internal virtual {}

    function _removeCollateralFromAccount(address _subAccount, uint8 collateralId, uint80 amount) internal virtual {}

    function _increaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _decreaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _increaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _decreaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _exerciseTokenInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _settleAccount(address _subAccount, int80 payout) internal virtual {}

    /**
     * ========================================================= *
     *                View functions to override
     * ========================================================= *
     */

    /**
     * @notice [MUST Implement] return amount of collateral that should be reserved to payout the counterparty
     * @dev    if payout is positive: the account need to payout, the amount will be subtracted from collateral
     *         if payout is negative: the account will receive payout, the amount will be added to collateral
     *
     * @dev    this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view virtual returns (uint8 collateralId, int80 payout) {}

    /**
     * @dev [MUST Implement] return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view virtual returns (bool) {}

    /**
     * @dev reverts if the account cannot add this token into the margin account.
     * @param tokenId tokenId
     */
    function _verifyLongTokenIdToAdd(uint256 tokenId) internal view virtual {}

    /**
     * ========================================================= **
     *                Internal view functions
     * ========================================================= *
     */

    /**
     * @notice revert if the msg.sender is not authorized to access an subAccount id
     * @param _subAccount subaccount id
     */
    function _assertCallerHasAccess(address _subAccount) internal virtual {
        if (_isPrimaryAccountFor(msg.sender, _subAccount)) return;

        // the sender is not the direct owner. check if they're authorized
        uint160 maskedAccountId = (uint160(_subAccount) | 0xFF);

        uint256 allowance = allowedExecutionLeft[maskedAccountId][msg.sender];
        if (allowance == 0) revert NoAccess();

        // if allowance is not set to max uint256, reduce the number
        if (allowance != type(uint256).max) allowedExecutionLeft[maskedAccountId][msg.sender] = allowance - 1;
    }

    /**
     * @notice return if {_primary} address is the primary account for {_subAccount}
     */
    function _isPrimaryAccountFor(address _primary, address _subAccount) internal pure returns (bool) {
        return (uint160(_primary) | 0xFF) == (uint160(_subAccount) | 0xFF);
    }

    /**
     * @dev check if msg.sender is the marginAccount
     */
    function _checkIsPomace() internal view {
        if (msg.sender != address(pomace)) revert NoAccess();
    }
}
