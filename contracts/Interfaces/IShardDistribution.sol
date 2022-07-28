// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IShardDistribution is IERC20 {

   function createInitialShards(
        uint _productUID, 
        uint _initialContributorShare, 
        uint _labShare, 
        uint _rejuveShare, 
        address _labShardHolder, 
        address _rejuveShardHolder
    ) external;

    function createFutureShards(
        uint _productUID, 
        uint _futureContributorShare, 
        uint _clinicNegotiatedCredit, 
        address _clinicShardHolder
    ) external;

    function parentToken() external view returns(address);
    function parentTokenId() external view returns(uint256);
    function getTargetSupply() external view returns(uint);
    function decimals() external view returns (uint8);
}