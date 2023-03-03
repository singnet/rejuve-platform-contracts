// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IProductShards is IERC1155 {
    function totalShardSupply(uint _productUID) external view returns (uint);

    function targetSupply(uint _productUID) external view returns (uint);

    function getShardsConfig(
        uint _productUID
    ) external view returns (uint, uint8, uint8, uint8);

    function getProductIDs(
        uint productUID
    ) external view returns (uint[] memory);
}
