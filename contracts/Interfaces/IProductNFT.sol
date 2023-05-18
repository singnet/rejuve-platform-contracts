// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IProductNFT is IERC721 {
    function createProduct(
        uint256 _productCreatorId,
        uint256 _productUID,
        string memory _productURI,
        bytes[] memory _dataHashes,
        uint256[] memory _creditScores
    ) external;

    function linkNewData(
        uint256 _productUID,
        bytes[] memory _newDataHashes,
        uint256[] memory _creditScores
    ) external;

    function getProductToData(
        uint256 _productUID
    ) external view returns (bytes[] memory);

    function getDataCredit(
        bytes memory _dHash,
        uint256 _productUID
    ) external view returns (uint256);

    function getDataOwnerAddress(
        bytes memory _dHash
    ) external view returns (address);

    function getInitialDataLength(
        uint256 _productUID
    ) external view returns (uint256);
}
