// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IProductShards is IERC20 {
    function createShardsByAdmin(uint _productUID) external;
    function parentToken() external view returns(address _parentToken);
    function parentTokenId() external view returns(uint256 _parentTokenId);
    function getSharePrice() external view returns (uint);
    function decimals() external view returns (uint8);
}