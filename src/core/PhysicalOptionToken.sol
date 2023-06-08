// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// external libraries
import {ERC1155} from "solmate/tokens/ERC1155.sol";

// interfaces
import {IPhysicalOptionToken} from "../interfaces/IPhysicalOptionToken.sol";
import {IPomace} from "../interfaces/IPomace.sol";
import {IPhysicalOptionTokenDescriptor} from "../interfaces/IPhysicalOptionTokenDescriptor.sol";

// constants and types
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   PhysicalOptionToken
 * @author  antoncoding
 * @dev     each PhysicalOptionToken represent the right to redeem cash value at expiry.
 *             The value of each OptionType should always be positive.
 */
contract PhysicalOptionToken is ERC1155, IPhysicalOptionToken {
    ///@dev pomace serve as the registry
    IPomace public immutable pomace;
    IPhysicalOptionTokenDescriptor public immutable descriptor;

    constructor(address _pomace, address _descriptor) {
        // solhint-disable-next-line reason-string
        if (_pomace == address(0)) revert();
        pomace = IPomace(_pomace);

        descriptor = IPhysicalOptionTokenDescriptor(_descriptor);
    }

    /**
     *  @dev return string as defined in token descriptor
     *
     */
    function uri(uint256 id) public view override returns (string memory) {
        return descriptor.tokenURI(id);
    }

    /**
     * @dev mint option token to an address. Can only be called by corresponding margin engine
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     */
    function mint(address _recipient, uint256 _tokenId, uint256 _amount) external override {
        pomace.checkEngineAccessAndTokenId(_tokenId, msg.sender);

        _mint(_recipient, _tokenId, _amount, "");
    }

    /**
     * @dev burn option token from an address. Can only be called by corresponding margin engine
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burn(address _from, uint256 _tokenId, uint256 _amount) external override {
        pomace.checkEngineAccess(_tokenId, msg.sender);

        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burnPomaceOnly(address _from, uint256 _tokenId, uint256 _amount) external override {
        _checkIsPomace();
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn batch of option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     *
     */
    function batchBurnPomaceOnly(address _from, uint256[] memory _ids, uint256[] memory _amounts) external override {
        _checkIsPomace();
        _batchBurn(_from, _ids, _amounts);
    }

    /**
     * @dev check if msg.sender is the marginAccount
     */
    function _checkIsPomace() internal view {
        if (msg.sender != address(pomace)) revert NoAccess();
    }
}
