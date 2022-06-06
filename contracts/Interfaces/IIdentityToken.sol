// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IIdentityToken is IERC721 {

    function createIdentity(string memory _tokenURI) external;
    function burnIdentity(uint _tokenId) external;
    function getOwnerIdentity(address _owner) external view returns(uint);
    function ifRegistered(address _userAddress) external view returns(uint8);

}