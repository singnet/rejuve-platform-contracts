// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/RFT.sol";
import "./ProductNFTAbstract.sol";

contract ProductShards is ERC20, ERC20Capped, IERC721Receiver, RFT, Ownable {

    enum RewardStatus { NotRewarded, Rewarded }

    // Product NFT contract address
    address private _productNFT; 

    // Product NFT token ID
    uint productNftID; 

    // Initial buy price for entrepreneurs
    uint sharePrice; 

    // Share fraction division
    uint8 shareDecimal;    

    // Mapping from user to share reward status 
    mapping(address => RewardStatus) userToReward; 

    /**
     * @dev Emitted when product shares are distributed 
    */
    event ShardDistributed(uint productUID, address dataOwner, uint share);

    constructor(
        string memory name_,
        string memory symbol_,
        uint cap_,
        address productNFT_,
        uint productNftID_,
        uint sharePrice_,
        uint8 shareDecimal_
    ) 
        ERC20 (name_,symbol_)
        ERC20Capped (cap_)
    {
        _productNFT = productNFT_;
        productNftID = productNftID_;
        sharePrice = sharePrice_;
        shareDecimal = shareDecimal_;
    }

//----------------- Step 6: Product Shards Creation & Distribution - Transaction by Lab / Rejuve ---------------

    /**
     * @notice Shards creation and distribution to data contributors
     * @dev Rejuve admin OR Lab can initiate the transaction - up to business requirement - add modifier accordingly
     * 
     * Steps:
     * 
     * 1. Transfer ownership of Product NFT to this RFT contract
     * 2. Create & distribute shards 
     * 
     * @param _productUID product unique ID 
    */
    function createShardsByAdmin(uint _productUID) external onlyOwner { 
        _transferNFTownership(_productUID);
        _createShard(_productUID);
    }

// ------------------------------------- Other External Views ---------------------------------------------------

    function parentToken() external view override returns(address _parentToken){
        return address(_productNFT);
    }

    function parentTokenId() external view override returns(uint256 _parentTokenId){
        return productNftID;
    }

    function getSharePrice() external view returns (uint) {
        return sharePrice;
    }

//---------------------------------- PUBLIC OVERRIDE -----------------------------------------------------------
    
    function decimals() public view override returns (uint8) {
        return shareDecimal;
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
//---------------------------------------------- PRIVATE ------------------------------------------------

    /**
     * @notice Transfer product NFT ownership to this contract
     * @param _productUID product unique ID 
    */
    function _transferNFTownership(uint _productUID) private { 
        // check if this contract is approved to call tranferFrom
        ProductNFTAbstract productNFT = ProductNFTAbstract(_productNFT);
        productNFT.safeTransferFrom(msg.sender, address(this), _productUID);
    }

    /**
     * @dev Private function to create shards and their distribution 
     * 
     * Steps:
     * 
     * 1. Get all data hashes used in the product 
     * 2. Get data owner address 
     * 3. Get credit score against each data hash
     * 4. Calculate share for each contributor based on credit score
     * 5. Check if calculated share <= target shares left to be minted 
     * 6. Mint & Assign shards to each contributor 
    */
    function _createShard(uint _productUID) private { 
        
        ProductNFTAbstract productNFT = ProductNFTAbstract(_productNFT);
        bytes32[] memory productDataHashes = getData(_productUID);

        for(uint i = 0; i < productDataHashes.length; i++){
            address dataOwner = productNFT.getDataOwnerAddress(productDataHashes[i]);

            require(userToReward[dataOwner] == RewardStatus.NotRewarded, "REJUVE: Already rewarded");

            uint ownerShareAmount = _calculateShareAmount(productNFT.getDataCredit(productDataHashes[i], _productUID));  
            
            //require(ownerShareAmount <= totalShareLeft(), "REJUVE: Exceed share amount");
            
            _mint(dataOwner, ownerShareAmount); 
            userToReward[dataOwner] = RewardStatus.Rewarded;    

            emit ShardDistributed(_productUID, dataOwner, ownerShareAmount);
        }
    }

    /**
     * @dev Returns all data hashes used in the product 
    */ 
    function getData(uint _productUID) private view returns(bytes32[] memory) {
        ProductNFTAbstract productNFT = ProductNFTAbstract(_productNFT);
        bytes32[] memory productData = productNFT.getProductToData(_productUID);
        return productData;
    }

    /**
     * @dev calculate share amount of a data contributor in a specific product 
     * as per credit score 
    */ 
    function _calculateShareAmount(uint _creditScore) private pure returns(uint) {
        uint share = _creditScore;  // how credit score will be converted to share amount ? 
        return share; 
    }

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Capped) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }


 
}