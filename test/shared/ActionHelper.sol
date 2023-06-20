// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/config/enums.sol";
import "../../src/config/types.sol";

import "../../src/libraries/TokenIdUtil.sol";
import "../../src/libraries/PhysicalActionUtil.sol";

abstract contract ActionHelper {
    function getTokenId(TokenType tokenType, uint32 productId, uint256 expiry, uint256 strike, uint256 exerciseWindow)
        internal
        pure
        returns (uint256 tokenId)
    {
        tokenId = TokenIdUtil.getTokenId(tokenType, productId, uint64(expiry), uint64(strike), uint64(exerciseWindow));
    }

    function parseTokenId(uint256 tokenId)
        internal
        pure
        returns (TokenType tokenType, uint32 productId, uint64 expiry, uint64 strike, uint64 exerciseWindow)
    {
        return TokenIdUtil.parseTokenId(tokenId);
    }

    function createAddCollateralAction(uint8 collateralId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createAddCollateralAction(collateralId, amount, from);
    }

    function createRemoveCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createRemoveCollateralAction(collateralId, amount, recipient);
    }

    function createTransferCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createTransferCollateralAction(collateralId, amount, recipient);
    }

    function createMintAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createMintAction(tokenId, amount, recipient);
    }

    function createMintIntoAccountAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createMintIntoAccountAction(tokenId, amount, recipient);
    }

    function createBurnAction(uint256 tokenId, address from, uint256 amount) internal pure returns (ActionArgs memory action) {
        return PhysicalActionUtil.createBurnAction(tokenId, amount, from);
    }

    function createTransferLongAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createTransferLongAction(tokenId, amount, recipient);
    }

    function createTransferShortAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createTransferShortAction(tokenId, amount, recipient);
    }

    function createAddLongAction(uint256 tokenId, uint256 amount, address from)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createAddLongAction(tokenId, amount, from);
    }

    function createRemoveLongAction(uint256 tokenId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return PhysicalActionUtil.createRemoveLongAction(tokenId, amount, recipient);
    }

    function createExerciseTokenAction(uint256 tokenId, uint256 amount) internal pure returns (ActionArgs memory action) {
        return PhysicalActionUtil.createExerciseTokenAction(tokenId, amount);
    }

    function createSettleAction() internal pure returns (ActionArgs memory action) {
        return PhysicalActionUtil.createSettleAction();
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testForgeCoverageIgnoreThis() public {}
}
