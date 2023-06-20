// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";
import {BytesArrayUtil} from "../../src/libraries/BytesArrayUtil.sol";

import "../../src/config/constants.sol";
import "../../src/config/errors.sol";
import "../../src/config/types.sol";

/**
 * Basic tests
 */
contract BytesArrayUtilTest is Test {
    function testAppend() public {
        bytes32[] memory arr = new bytes32[](2);
        arr[0] = keccak256(abi.encode(1, 2, block.timestamp + 14 days));
        arr[1] = keccak256(abi.encode(1, 3, block.timestamp + 14 days));

        bytes32 value = keccak256(abi.encode(3, 2, block.timestamp + 7 days));

        bytes32[] memory result = BytesArrayUtil.append(arr, value);

        assertEq(result.length, 3);

        assertEq(result[0], arr[0]);
        assertEq(result[1], arr[1]);
        assertEq(result[2], value);
    }

    function testIndexOf() public {
        bytes32[] memory arr = new bytes32[](2);
        arr[0] = keccak256(abi.encode(1, 2, block.timestamp + 14 days));
        arr[1] = keccak256(abi.encode(1, 3, block.timestamp + 14 days));

        bool found;
        uint256 index;

        (found, index) = BytesArrayUtil.indexOf(arr, keccak256(abi.encode(1, 2, block.timestamp + 14 days)));
        assertTrue(found);
        assertEq(index, 0);

        (found, index) = BytesArrayUtil.indexOf(arr, keccak256(abi.encode(1, 3, block.timestamp + 14 days)));
        assertTrue(found);
        assertEq(index, 1);

        (found, index) = BytesArrayUtil.indexOf(arr, keccak256(abi.encode(1, 3, block.timestamp + 7 days)));
        assertFalse(found);
        assertEq(index, 0);
    }
}
