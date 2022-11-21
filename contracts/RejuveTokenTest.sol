// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RejuveTokenTest is ERC20, Ownable {

    constructor(
        string memory name_, 
        string memory symbol_
    ) 
        ERC20(name_,symbol_) 
    {
        _mint(msg.sender, 100 * 10**uint256(2)); // 10,000
    }

    function mint(
        uint _amountToBeMinted
    ) 
        external 
        onlyOwner
    {
        _mint(msg.sender,_amountToBeMinted);
    }

}