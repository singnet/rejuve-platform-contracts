// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "./Interfaces/RFT.sol";
import "./ShardAdministration.sol";

/**
 * @notice Shards Distribution Phases:
 * 
 * Phase 1:
 * Initial data contributors, Lab and Rejuve will be getting shards
 *
 * Phase 2:
 * Future data contributors will be getting shards
 *
 * @dev This contract module provides "Phase 1" initial shard creation & 
 * distribution mechanism that allows a minter to create and distribute shards to,

 * 1. Initial data contributors
 * 2. Lab (Contributing research proposal) 
 * 3. The platform, Rejuve
 *
 * Also, if some initial shards remaining to be minted, a minter 
 * can create and assign to rejuve platform later. 
 *
*/

contract ShardDistribution is ShardAdministration, ERC20, IERC721Receiver, RFT {

    // Total supply to be minted
    uint _targetShardSupply;

    // Share fraction division
    uint8 private _shareDecimal;    

    // Addresses of all initial contributors 
    address[] private _initialDataOwners;

    // Shard amount of all initial contributors 
    uint[] private _initialDataOwnerShards;

    // Initial cocontributor reward status 
    bool initialContributorReward;

    /**
     * @dev Emitted when product shards are distributed to data contributors
    */
    event ShardDistributed(uint productUID, address[] dataOwners, uint[] shardAmount);

    /**
     * @dev Emitted when product shards are distributed to data contributors
    */
    event ShardDistributedToLab(uint productUID, address lab, uint amount);

    /**
     * @dev Emitted when product shards are distributed to data contributors
    */
    event ShardDistributedToRejuve(uint productUID, address rejuve, uint amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 shareDecimal_,
        uint targetShardSupply_,
        uint productNftID_,
        IProductNFT productNFT_,
        address rejuveAdmin_
    ) 
        ERC20 (name_,symbol_)
        ShardAdministration(rejuveAdmin_, productNFT_, productNftID_)
    {
        _shareDecimal = shareDecimal_;
        _targetShardSupply = targetShardSupply_ * 10**uint256(shareDecimal_);
    }

    modifier checkRewardStatus(bool _rewardStatus) {
        require (!_rewardStatus, "REJUVE: Already Rewarded");
        _;
    }
    
//----------------------- Step#6 (Phase 1): Product Shards Creation & Distribution ---------------------

    /**
     * @notice Shards creation and distribution to initial data contributors, Lab and rejuve
     * @dev Lab / Rejuve admin can initiate the transaction 
     * 
     * Steps:
     * 
     * 1. Transfer ownership of "Product NFT" to this contract (RFT)
     * 2. Create & Assign initial data contributors shards 
     * 3. Create & Assign lab shards
     * 4. Create & Assign rejuve shards
     * 
     * @param _productUID product NFT ID 
    */
    function createInitialShards(
        uint _productUID, 
        uint _initialContributorShare, 
        uint _labShare, 
        uint _rejuveShare, 
        address _labShardHolder, 
        address _rejuveShardHolder
    )
        external 
        whenNotPaused
        checkRewardStatus(initialContributorReward)
    {  
        require(hasRole(MINTER_ROLE, _msgSender()), "REJUVE: Must have minter role to mint shards");
        _transferNftOwnership(_productUID);
        _createInitialContributorShards(_productUID, _initialContributorShare);
        _createLabShards(_productUID, _labShare, _labShardHolder);
        _createRejuveShards(_productUID, _rejuveShare, _rejuveShardHolder);
    }  

// --------------------------------------- External Views -----------------------------------------------

    // Returns product NFT address
    function parentToken() external view override returns(address) {
        return address(productNFT);
    }

    // Returns product NFT ID
    function parentTokenId() external view override returns(uint) {
        return productNftID;
    }

    // Returns target shards supply
    function getTargetSupply() external view returns(uint) {
        return _targetShardSupply;
    }

//--------------------------------------------- PUBLIC ---------------------------------------------------
    
    /**
     * @dev Returns smallest division per shard 
    */
    function decimals() public view override returns (uint8) {
        return _shareDecimal;
    }

    /**
     * @dev See {IERC721Receiver}
    */
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
//---------------------------------------------- INTERNAL ----------------------------------------------

    /**
     * @notice Mint shards and assign to given account
    */
    function _mintShard(
        address account, 
        uint256 amount
    ) internal {
        require(totalSupply() + amount <= _targetShardSupply, "REJUVE: Cap exceeded");
        _mint(account, amount);
    }

    /**
     * @dev Calculate shards Amount for individual data contributor
     * 
     * Steps:
     * 1. Get individual percentage contribution using data credit score 
     * 2. Get total shards available for data contributor category
     * 3. Calculate shard amount as per percentage for individual data contributor
    */
    function _calculateContributorShards(
        uint _creditScore, 
        uint _totalCreditScores, 
        uint _contributorShare
    ) 
        internal 
        view 
        returns(uint) 
    {
        uint _contributorShardsPercent = (100 * _creditScore) / _totalCreditScores; 
        uint total = _calculateTotalShards(_contributorShare); 
        uint shardAmount = (total * _contributorShardsPercent) / 100; 
        return shardAmount;
    }

    /**
     * @return uint total shard amount available for data contributor category
    */ 
    function _calculateTotalShards(uint _share) internal view returns(uint) {
        uint shardAmount = (_targetShardSupply * _share) / 100;
        return shardAmount;
    }

    /**
     * @return bytes[] all data hashes used in the product 
    */ 
    function _getData(uint _productUID) internal view returns(bytes[] memory) {
        bytes[] memory productData = productNFT.getProductToData(_productUID);
        return productData;
    }

//---------------------------------------------- PRIVATE ------------------------------------------------

    /**
     * @notice Transfer product NFT ownership to this contract
    */
    function _transferNftOwnership(uint _productUID) private { 
        require(productNFT.getApproved(_productUID) == address(this), "REJUVE: Not approved");
        productNFT.safeTransferFrom(msg.sender, address(this), _productUID);
    }

    /**
     * @dev Private function to create shards and their distribution 
     * @param _initialContributorShare initial data contributor share %
     * 
     * Steps:
     * 
     * 1. Get all data hashes used in the product 
     * 2. Get sum of all data credits => total initial data credits
     * 3. Get data owner address 
     * 4. Get credit score against each data hash
     * 5. Calculate share for each contributor based on credit score
     * 7. Mint & Assign shards to each contributor 
    */
    function _createInitialContributorShards(
        uint _productUID, 
        uint _initialContributorShare
    ) private { 
        bytes[] memory productDataHashes = _getData(_productUID);
        uint totalCredits = _getTotalInitialCredits(_productUID);

        for(uint i = 0; i < productNFT.getInitialDataLength(_productUID); i++){

            address dataOwner = productNFT.getDataOwnerAddress(productDataHashes[i]);
            uint shardAmount = _calculateContributorShards(productNFT.getDataCredit(productDataHashes[i], _productUID), totalCredits, _initialContributorShare); 
            _mintShard(dataOwner, shardAmount); 
            _initialDataOwners.push(dataOwner);
            _initialDataOwnerShards.push(shardAmount);

        }

        initialContributorReward = true;
        emit ShardDistributed(_productUID, _initialDataOwners, _initialDataOwnerShards);
    }

    /**
     * @dev create shards for lab
     * - calculate shard amount using lab share
     * @param _labShare lab share %
     * @param _labShardHolder lab account for holding shards
     */
    function _createLabShards(
        uint _productUID, 
        uint _labShare, 
        address _labShardHolder
    ) private {
        uint amount = _calculateTotalShards(_labShare);
        _mintShard(_labShardHolder, amount);

        emit ShardDistributedToLab(_productUID, _labShardHolder, amount);
    }

    /**
     * @dev create shards for lab
     * - calculate shard amount using lab share
     * @param _rejuveShare Rejuve share %
     * @param _rejuveShardHolder Rejuve account for holding shards
     */
    function _createRejuveShards(
        uint _productUID, 
        uint _rejuveShare, 
        address _rejuveShardHolder
    ) private {
        uint amount = _calculateTotalShards(_rejuveShare);
        _mintShard(_rejuveShardHolder, amount);

        emit ShardDistributedToRejuve(_productUID, _rejuveShardHolder, amount);
    }

    /**
     * @return uint sum of all initial data credits 
    */ 
    function _getTotalInitialCredits(uint _productUID) private view returns(uint) {
        bytes[] memory productDataHashes = _getData(_productUID);
        uint _totalInitialCredits;

        for(uint i = 0; i < productDataHashes.length; i++){

            uint dataCredit = productNFT.getDataCredit(productDataHashes[i], _productUID); 
            _totalInitialCredits = _totalInitialCredits + dataCredit;

        }

        return _totalInitialCredits;
    }

}




