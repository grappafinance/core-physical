// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

import "../../config/enums.sol";

contract TokenIdUtilTest is Test {
    function testTokenIdHigherThan0(uint8 tokenType, uint32 productId, uint64 expiry, uint64 strike, uint64 exerciseWindow)
        public
    {
        vm.assume(tokenType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(TokenType(tokenType), productId, expiry, strike, exerciseWindow);

        assertGt(id, 0);
    }

    function testFormatAndParseAreMirrored(uint8 tokenType, uint32 productId, uint64 expiry, uint64 strike, uint64 exerciseWindow)
        public
    {
        vm.assume(tokenType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(TokenType(tokenType), productId, expiry, strike, exerciseWindow);
        (TokenType _tokenType, uint32 _productId, uint64 _expiry, uint64 _strike, uint64 _exerciseWindow) =
            TokenIdUtil.parseTokenId(id);

        assertEq(uint8(tokenType), uint8(_tokenType));
        assertEq(productId, _productId);
        assertEq(expiry, _expiry);
        assertEq(strike, _strike);
        assertEq(exerciseWindow, _exerciseWindow);
    }

    function testGetAndParseAreMirrored(uint8 tokenType, uint32 productId, uint256 expiry, uint256 strike, uint256 exerciseWindow)
        public
    {
        vm.assume(tokenType < 2);
        vm.assume(productId > 0);

        uint256 id =
            TokenIdUtil.getTokenId(TokenType(tokenType), productId, uint64(expiry), uint64(strike), uint64(exerciseWindow));
        (TokenType _tokenType, uint32 _productId, uint64 _expiry, uint64 _strike, uint64 _exerciseWindow) =
            TokenIdUtil.parseTokenId(id);

        assertEq(tokenType, uint8(_tokenType));
        assertEq(productId, _productId);
        assertEq(uint64(expiry), _expiry);
        assertEq(uint64(strike), _strike);
        assertEq(uint64(exerciseWindow), _exerciseWindow);
    }
}
