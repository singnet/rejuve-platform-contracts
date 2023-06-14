// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IIdentityToken is IERC721 {
    function createIdentity(
        bytes memory _signature,
        address _userAccount,
        string memory _tokenURI,
        uint256 _nonce
    ) external;

    function burnIdentity(uint56 _tokenId) external;

    function getOwnerIdentity(address _owner) external view returns (uint256);

    function ifRegistered(address _userAddress) external view returns (uint8);
}
