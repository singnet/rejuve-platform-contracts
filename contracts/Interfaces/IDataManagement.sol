// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDataManagement {

    function submitData(address _signer, bytes memory _signature, bytes memory _dHash, uint256 _nonce) external;
    function getPermission(address _signer, bytes memory _signature, bytes memory _dHash, uint256 _requesterId, uint256 _nextProductUID, uint256 _nonce, uint256 _expiration) external;
    function getDataByTokenId(uint _tokenId, uint _index) external view returns(bytes memory);
    function getPermissionStatus(bytes memory _dHash, uint _productUID) external view returns(uint8);
    function getDataOwnerId(bytes memory _dHash) external view returns(uint); 
    function getPermissionDeadline(bytes memory _dHash, uint _nextProductUID) external view returns(uint);
}