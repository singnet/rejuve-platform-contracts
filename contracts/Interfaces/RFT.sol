// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Note: the ERC-165 identifier for this interface is 0x5755c3f2.
interface RFT /* is ERC20, ERC165 */ {

  function parentToken() external view returns(address _parentToken);
  function parentTokenId() external view returns(uint256 _parentTokenId);

}