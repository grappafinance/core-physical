// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPhysicalOptionToken {
    /**
     * @dev mint option token to an address. Can only be called by corresponding margin engine
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     *
     */
    function mint(address _recipient, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn option token from an address. Can only be called by corresponding margin engine
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burn(address _from, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn option token from an address. Can only be called by pomace, used for settlement
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     *
     */
    function burnPomaceOnly(address _from, uint256 _tokenId, uint256 _amount) external;

    /**
     * @dev burn batch of option token from an address. Can only be called by pomace
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     *
     */
    function batchBurnPomaceOnly(address _from, uint256[] memory _ids, uint256[] memory _amounts) external;
}
