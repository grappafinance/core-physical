// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {OptionToken} from "../../core/OptionToken.sol";
import {Pomace} from "../../core/Pomace.sol";
import {OptionTokenDescriptor} from "../../core/OptionTokenDescriptor.sol";
import "../../libraries/TokenIdUtil.sol";
import "../../libraries/ProductIdUtil.sol";
import "../../config/errors.sol";

contract OptionTokenTest is Test {
    OptionToken public option;

    address public pomace;
    address public nftDescriptor;

    function setUp() public {
        pomace = address(new Pomace(address(0), address(0)));

        nftDescriptor = address(new OptionTokenDescriptor());

        option = new OptionToken(pomace, nftDescriptor);
    }

    function testCannotMint() public {
        uint8 engineId = 1;

        // put in valid tokenId
        uint32 productId = ProductIdUtil.getProductId(engineId, 0, 0, 0);
        uint256 expiry = block.timestamp + 1 days;
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, uint64(expiry), 20, 40);

        vm.expectRevert(PM_Not_Authorized_Engine.selector);
        option.mint(address(this), tokenId, 1000_000_000);
    }

    function testCannotBurn() public {
        vm.expectRevert(PM_Not_Authorized_Engine.selector);
        option.burn(address(this), 0, 1000_000_000);
    }

    function testCannotBurnPomaceOnly() public {
        vm.expectRevert(NoAccess.selector);
        option.burnPomaceOnly(address(this), 0, 1000_000_000);

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        vm.expectRevert(NoAccess.selector);
        option.batchBurnPomaceOnly(address(this), ids, amounts);
    }

    function testCannotMintZeroSettlementWindow() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(pomace, abi.encodeWithSelector(Pomace(pomace).engines.selector, engineId), abi.encode(address(this)));

        uint32 productId = ProductIdUtil.getProductId(engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, uint64(expiry), 40, 0);

        vm.expectRevert(PM_InvalidSettlementWindow.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testGetUrl() public {
        assertEq(option.uri(0), "https://grappa.finance/token/0");

        assertEq(option.uri(200), "https://grappa.finance/token/200");
    }
}
