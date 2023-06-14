// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {MockedBaseEngineSetup} from "./base-engine/MockedBaseEngineSetup.sol";

import "../../src/config/types.sol";
import "../../src/config/errors.sol";

contract PomaceAccessTest is MockedBaseEngineSetup {
    uint256 private depositAmount = 100 * 1e6;

    address private subAccountIdToModify;

    function setUp() public {
        engine.setIsAboveWater(true);

        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        subAccountIdToModify = address(uint160(alice) ^ uint160(1));
    }

    function testCannotUpdateRandomAccount() public {
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testAliceCanGrantAccessToMaxSubAccount() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 1);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAccount(address(uint160(alice) ^ uint160(255)), true);
    }

    function testAliceCannotGrantAccessToMaxSubAccountPlusOne() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 1);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAccount(address(uint160(alice) ^ uint160(256)), false);
    }

    function testAliceCanGrantAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 1);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAccount(subAccountIdToModify, true);
    }

    function testAllowanceDecrease() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 2);
        vm.stopPrank();

        _assertCanAccessAccount(subAccountIdToModify, true);
        assertEq(engine.allowedExecutionLeft(uint160(alice) | 0xFF, address(this)), 1);
        _assertCanAccessAccount(subAccountIdToModify, true);
        assertEq(engine.allowedExecutionLeft(uint160(alice) | 0xFF, address(this)), 0);

        // no access left
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testGranteeCanRevokeAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 2);
        vm.stopPrank();

        // reset allowance to 0!
        engine.revokeSelfAccess(alice);

        // no access left
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testAliceCanRevokeAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(subAccountIdToModify, true);

        // alice revoke access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), 0);
        vm.stopPrank();

        // no longer has access to subaccount!
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function _assertCanAccessAccount(address subAccountId, bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);

        if (!_canAccess) vm.expectRevert(NoAccess.selector);

        engine.execute(subAccountId, actions);
    }
}
