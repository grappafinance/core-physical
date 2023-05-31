// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Pomace} from "../../core/Pomace.sol";
import {PomaceProxy} from "../../core/PomaceProxy.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import {MockPomaceV2} from "../mocks/MockPomaceV2.sol";

import "../../config/errors.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract PomaceProxyTest is Test {
    Pomace public implementation;
    Pomace public pomace;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);

        implementation = new Pomace(address(0), address(0));
        bytes memory data = abi.encodeWithSelector(Pomace.initialize.selector, address(this));

        pomace = Pomace(address(new PomaceProxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize(address(this));
    }

    function testProxyOwnerIsSelf() public {
        assertEq(pomace.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        pomace.initialize(address(this));
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        pomace.upgradeTo(address(1));
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockPomaceV2 v2 = new MockPomaceV2();

        pomace.upgradeTo(address(v2));

        assertEq(MockPomaceV2(address(pomace)).version(), 2);
    }

    function testCannotUpgradeTov3() public {
        MockPomaceV2 v2 = new MockPomaceV2();
        MockPomaceV2 v3 = new MockPomaceV2();

        pomace.upgradeTo(address(v2));

        vm.expectRevert("not upgrdable anymore");
        pomace.upgradeTo(address(v3));
    }
}
