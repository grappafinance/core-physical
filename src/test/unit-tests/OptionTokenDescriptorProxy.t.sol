// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {OptionTokenDescriptor} from "../../core/OptionTokenDescriptor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import {MockTokenDescriptorV2} from "../mocks/MockOptionTokenDescriptorV2.sol";

import "../../config/errors.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract OptionProxyTest is Test {
    OptionTokenDescriptor public implementation;
    OptionTokenDescriptor public descriptor;

    constructor() {
        implementation = new OptionTokenDescriptor();
        bytes memory data = abi.encode(OptionTokenDescriptor.initialize.selector);

        descriptor = OptionTokenDescriptor(address(new ERC1967Proxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize();
    }

    function testProxyOwnerIsCorrect() public {
        assertEq(descriptor.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        descriptor.initialize();
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        descriptor.upgradeTo(address(1));
    }

    function testGetUrl() public {
        assertEq(descriptor.tokenURI(0), "https://grappa.finance/token/0");
        assertEq(descriptor.tokenURI(200), "https://grappa.finance/token/200");
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockTokenDescriptorV2 v2 = new MockTokenDescriptorV2();

        descriptor.upgradeTo(address(v2));

        assertEq(descriptor.tokenURI(0), "https://grappa.finance/token/v2/0");
        assertEq(descriptor.tokenURI(200), "https://grappa.finance/token/v2/200");
    }
}
