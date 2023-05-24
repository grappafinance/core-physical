// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

/**
 * @dev tester contract to make coverage works
 */
contract TokenIdUtilTester {
    function getTokenId(TokenType tokenType, uint32 productId, uint64 expiry, uint64 strike, uint64 settlementWindow)
        external
        pure
        returns (uint256 tokenId)
    {
        uint256 result = TokenIdUtil.getTokenId(tokenType, productId, expiry, strike, settlementWindow);
        return result;
    }

    function isExpired(uint256 tokenId) external view returns (bool expired) {
        bool result = TokenIdUtil.isExpired(tokenId);
        return result;
    }
}

/**
 * Tests to improve coverage
 */
contract TokenIdLibTest is Test {
    uint256 public constant base = UNIT;

    TokenIdUtilTester tester;

    function setUp() public {
        tester = new TokenIdUtilTester();
    }

    function testIsExpired() public {
        vm.warp(1671840000);

        uint64 expiry = uint64(block.timestamp + 1);
        uint256 tokenId = tester.getTokenId(TokenType.PUT, 0, expiry, 0, 0);
        assertEq(tester.isExpired(tokenId), false);

        uint64 expiry2 = uint64(block.timestamp - 1);
        uint256 tokenId2 = tester.getTokenId(TokenType.PUT, 0, expiry2, 0, 0);
        assertEq(tester.isExpired(tokenId2), true);
    }
}
