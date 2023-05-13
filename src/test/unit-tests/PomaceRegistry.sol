// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Pomace} from "../../core/Pomace.sol";
import {PomaceProxy} from "../../core/PomaceProxy.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import "../../config/errors.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";

/**
 * @dev test pomace register related functions
 */
contract PomaceRegistry is Test {
    Pomace public pomace;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);

        // set option to 0
        address pomaceImplementation = address(new Pomace(address(0))); // nonce: 5

        bytes memory data = abi.encode(Pomace.initialize.selector);

        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, data))); // 6
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        pomace.registerAsset(address(weth));
    }

    function testRegisterAssetFromId1() public {
        uint8 id = pomace.registerAsset(address(weth));
        assertEq(id, 1);

        assertEq(pomace.assetIds(address(weth)), id);
    }

    function testRegisterAssetRecordDecimals() public {
        uint8 id = pomace.registerAsset(address(weth));

        (address addr, uint8 decimals) = pomace.assets(id);

        assertEq(addr, address(weth));
        assertEq(decimals, 18);
    }

    function testCannotRegistrySameAssetTwice() public {
        pomace.registerAsset(address(weth));
        vm.expectRevert(PM_AssetAlreadyRegistered.selector);
        pomace.registerAsset(address(weth));
    }

    function testReturnAssetsFromProductId() public {
        pomace.registerAsset(address(weth));

        uint32 product = pomace.getProductId(address(0), address(weth), address(0), address(weth));

        (, address underlying,, address strike,, address collateral, uint8 collatDecimals) =
            pomace.getDetailFromProductId(product);

        assertEq(underlying, address(weth));

        // strike is empty
        assertEq(strike, address(0));
        assertEq(underlying, address(weth));
        assertEq(collateral, address(weth));
        assertEq(collatDecimals, 18);
    }

    function testReturnOptionDetailsFromTokenId() public {
        uint256 expiryTimestamp = block.timestamp + 14 days;
        uint256 strikePrice = 4000 * UNIT;

        pomace.registerAsset(address(weth));

        uint32 product = pomace.getProductId(address(0), address(weth), address(0), address(weth));
        uint256 token = pomace.getTokenId(TokenType.CALL, product, expiryTimestamp, strikePrice, 0);

        (TokenType tokenType, uint32 productId, uint256 expiry, uint256 longStrike, uint256 shortStrike) =
            pomace.getDetailFromTokenId(token);

        assertEq(uint8(tokenType), uint8(TokenType.CALL));
        assertEq(productId, product);

        // strike is empty
        assertEq(expiry, expiryTimestamp);
        assertEq(longStrike, strikePrice);
        assertEq(shortStrike, 0);
    }
}

/**
 * @dev test pomace functions around registering engines
 */
contract RegisterEngineTest is Test {
    Pomace public pomace;
    address private engine1;

    constructor() {
        engine1 = address(1);
        address pomaceImplementation = address(new Pomace(address(0))); // nonce: 5

        bytes memory data = abi.encode(Pomace.initialize.selector);

        pomace = Pomace(address(new PomaceProxy(pomaceImplementation, data))); // 6
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        pomace.registerEngine(engine1);
    }

    function testRegisterEngineFromId1() public {
        uint8 id = pomace.registerEngine(engine1);
        assertEq(id, 1);

        assertEq(pomace.engineIds(engine1), id);
    }

    function testCannotRegistrySameEngineTwice() public {
        pomace.registerEngine(engine1);
        vm.expectRevert(PM_EngineAlreadyRegistered.selector);
        pomace.registerEngine(engine1);
    }

    function testReturnEngineFromProductId() public {
        pomace.registerEngine(engine1);

        uint32 product = pomace.getProductId(address(engine1), address(0), address(0), address(0));

        (address engine,,,,,,) = pomace.getDetailFromProductId(product);

        assertEq(engine, engine1);
    }
}
