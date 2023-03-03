// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IRejuveToken is IERC20 {
    function burn(uint256 amount) external;
}
