// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../ProductNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Interfaces/RFT.sol";

contract ConfirmRFT {

    function confirmRFT(address _RFT) public view returns(bool) {

        address _NFT = RFT(_RFT).parentToken(); // returns address of NFT contract
        uint256 _tokenId = RFT(_RFT).parentTokenId(); // returns id of ID of NFT

        return
            ProductNFT(_NFT).supportsInterface(0x80ac58cd) && // confirm it is ERC-721
            ProductNFT(_NFT).ownerOf(_tokenId) == _RFT ; // confirm the owner of the NFT is the RFT contract address
    
    }
}