// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IProductShards is IERC1155 {
    function totalShardSupply(uint256 _productUID) external view returns (uint256);

    function targetSupply(uint256 _productUID) external view returns (uint256);

    function getShardsConfig(
        uint256 _productUID
    ) external view returns (uint256, uint8, uint8, uint8);

    function getProductIDs(
        uint256 productUID
    ) external view returns (uint256[] memory);
}
