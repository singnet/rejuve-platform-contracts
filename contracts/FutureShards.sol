// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "./ProductShards.sol";

/** @notice Contract module that provides product shards creation to future contributors.
 *  this is phase 2 of Product shards contract. 
 *
 * Phase 2:
 * 1. Shards Distribution to Future data contributors e.g. clinics 
 * 2. Remaining shards allocation 
 * 
 * @dev contract deployer is the default owner. 
 * - Only Owner can call initial, future and remaining shards allocation functions
 * - Only Owner can call pause/unpause functions
*/
contract FutureShards is ProductShards {

    // Shard amount of all future contributors 
    uint[] private _futureContributorShards;

    // Future contributor reward status 
    bool private _futureRewardDistributed;

    /**
     * @dev Emitted when product shards are distributed to future contributors
    */
    event FutureShardDistributed(
        uint productUID, 
        address[] dataOwners, 
        uint[] shardAmount
    );

    /**
     * @dev Emitted when remaining shards assigned to Rejuve - The Platform
    */
    event RemainingShardAllocated(
        uint productUID, 
        address rejuve, 
        uint shardAmount
    );
        
//------------------------------- Constructor -------------------------------------------//

    constructor(string memory uri_, address productNFT_) 
        ProductShards(uri_, productNFT_) 
    {}

//---------------------------------  EXTERNAL --------------------------------------------//    

    /**
     * @notice Shards creation and distribution to future data contributors e.g. clinics or any other entity 
     * @dev Rejuve (Who deploys the contract) can initiate the transaction 
     * 
     * Important:
     * 
     * 1. @param _futurePercent share % assigned to future contributors category out of total target
     * 2. @param _credits negotiated weights
     * 3. @param _futureContributors addresses of future contributors that are getting shards  
     *
    */
    function distributeFutureShards(
        uint _productUID,
        uint8 _futurePercent,
        uint[] memory _credits,
        address[] memory _futureContributors
    ) 
        external
        onlyOwner
        whenNotPaused 
    {
        _distributeFutureShards(_productUID, _futurePercent, _credits, _futureContributors);
    }

    /**
     * @dev Mint remaining shards (if left any) after initial and future shard distribution  
     * @dev Assign these shards to Rejuve or any other address provided in the input
    */
    function mintRemainingShards(
        uint _productUID, 
        address _holder
    ) 
        external 
        onlyOwner 
        whenNotPaused
    {
        _mintRemainingShards(_productUID, _holder);
    }

//---------------------------------------- PRIVATE ---------------------------------------------

    /**
     * @dev Private function to calculate & mint shards for future contributors
     * 
     * Steps:
     *
     * 1. Configure future contributor share in target supply
     * 2. Calculate total credits amount
     * 3. Mint shard for each future contributor as per their negotiated weight / credit
     */
    function _distributeFutureShards(
        uint _productUID,
        uint8 _futurePercent,
        uint[] memory _credits,
        address[] memory _futureContributors
    ) 
        private 
    {
        require(_futureContributors.length == _credits.length, "REJUVE: Not equal length");
        require(_futurePercent != 0, "REJUVE: Future percentage share cannot be zero");

        ShardConfig storage config = productToShardsConfig[_productUID];
        config.futurePercent = _futurePercent;      
        uint totalCredits = _totalFutureCredits(_credits);

        for (uint i = 0; i < _futureContributors.length; i++) {
            uint shardAmount = _shardsPerContributor(_credits[i], totalCredits, _futurePercent, config.targetSupply);     
            uint[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(_futureContributors[i], productToTypeIndexes[_productUID], amounts, "0x00" );

            config.totalSupply = config.totalSupply + shardAmount; 
            _futureContributorShards.push(shardAmount);
        }

        emit FutureShardDistributed(_productUID, _futureContributors, _futureContributorShards);
        _futureRewardDistributed = true;
    }

    /**
     * @dev Mint & assign remianing shards to Rejuve after initial & future shards allocation (if left any)
    */
    function _mintRemainingShards(
        uint _productUID, 
        address _holder
    ) 
        private 
    {
        require(_initialRewardDistributed && _futureRewardDistributed, "REJUVE: Cannot mint before initial & future distribution");
        ShardConfig storage config = productToShardsConfig[_productUID];
        uint amount = config.targetSupply - config.totalSupply;
        require(amount != 0, "REJUVE: No shard available");
            config.totalSupply = config.totalSupply + amount;
            uint[] memory amounts = _setAmount(amount); 
            for(uint i = 0; i < amounts.length; i++){
                _mint(_holder, productToTypeIndexes[_productUID][i], amounts[i], "0x00");
            }

            emit RemainingShardAllocated(_productUID, _holder, amount);
            
        
    }

//------------------------------------ Helpers---------------------------------------------//

    /**
     * @dev Calculate total future credits
    */
    function _totalFutureCredits(uint[] memory _credits) private pure returns(uint) {       
        uint totalCredits;  
        for (uint i = 0; i < _credits.length; i++) {
            totalCredits = totalCredits + _credits[i];
        }
        return totalCredits;
    }
}