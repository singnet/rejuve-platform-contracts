// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./ProductNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "./Interfaces/RFT.sol";

contract ProductShards is ERC20, IERC721Receiver, RFT  {

    uint public productShareSupply; // 100 shards per product NFT for test .  
    uint public sharePrice; // $1 for test
    uint public ProductNftID; 
    IERC721 public nft; // NFT address

    mapping(address=> mapping(uint=>uint)) userToProductToShare; // user to share amount

    constructor(
        string memory _name,
        string memory _symbol,
        address _nftAddress,
        uint _nftId,
        uint _shareSupply,
        uint _sharePrice
    ) 
        ERC20 (_name,_symbol)
    {
        nft = IERC721(_nftAddress);
        ProductNftID = _nftId;
        productShareSupply = _shareSupply;
        sharePrice = _sharePrice;

    }

    function transferNFTownership(uint _tokenId) public { // transfer NFT to this RFT contract
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function parentToken() external view override returns(address _parentToken){
        return address(nft);
    }

    function parentTokenId() external view override returns(uint256 _parentTokenId){
        return ProductNftID;
    }

    function totalSupply() public view override returns (uint256) {
        return productShareSupply;
    }

// ------------------------------------- Data Owners ----------------------------------------------------------

    function createShard(address _to, uint _productUID, uint _creditScore) internal { // create shard only for data contributor 
        _calculateShareAmount(_to,_productUID,_creditScore);
        _createShard(_to, userToProductToShare[_to][_productUID]);   
    }

    function _calculateShareAmount(address _to, uint _productUID, uint _creditScore) private {
        uint share = _creditScore;  // how credit score will be converted to share amount 
        userToProductToShare[_to][_productUID] = share;    
    }

    function _createShard(address _to, uint _shareAmount) private { // _to array of data owners - 
        _mint(_to,_shareAmount); // mint for all data contributor 
    }

//--------------------------------------- Entrepreneur -------------------------------------------------------

    function buyShare(uint _buyAmount , uint _productUID) external payable { // share purchased by entrepreneur 
        uint _msgValue = msg.value;
        uint tokenAmount = calculateAmount(_buyAmount);
        require(_msgValue >= tokenAmount , "REJUVE: Not Enough Amount");
        //require(_buyAmount<= totalSupply() - shards) check if share available
        _buyShare(msg.sender, _buyAmount, _productUID);
    }

    function calculateAmount(uint _buyAmount) private view returns(uint) {
        uint rejuveTokens = _buyAmount * sharePrice ;
        return rejuveTokens;
    }

    function _buyShare(address _to, uint _amount , uint _productUID) private {
        userToProductToShare[_to][_productUID] = _amount;
        _mint(_to, _amount); // mint or transfer for entrepreneur 
    }



}