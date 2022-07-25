// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./ShardDistribution.sol";

/**
 * @dev This contract module provides "Phase 2" future shard creation & 
 * distribution mechanism that allows a minter to create and distribute shards to,
 * 
 * 1. Future data contributors
 * 2. Clinics
 *
 * Also, after initial and future distribution, if any shard is left to be minted
 * from target supply, a minter can create and assign to rejuve platform later. 
*/

contract FutureDistribution is ShardDistribution  {

    // Addresses of all future data contributors 
    address[] private futureDataOwners;

    // Shard amount of all future contributors 
    uint[] private futureDataOwnerShards;

    // Future cocontributor reward status 
    bool private _futureContributorReward;

    // Fee % goes to data contributor with each resale of their shard
    uint private _curatorFee ;

    /**
     * @dev Emitted when product shards are distributed to data contributors
    */
    event RemainingShardDistributed(uint productUID, address rejuve, uint shardAmount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 shareDecimal_,
        uint targetShardSupply_,
        uint productNftID_,
        IProductNFT productNFT_,
        address rejuveAdmin_,  
        uint curatorFee_      
    )
        ShardDistribution(name_, symbol_, shareDecimal_, targetShardSupply_, productNftID_, productNFT_, rejuveAdmin_)
    {
        _curatorFee = curatorFee_;
    }
        
//----------------------- Step#6 (Phase 2): Product Shards Creation & Distribution ---------------------

    /**
     * @notice Shards creation and distribution to future data contributors 
     * @dev Caller with Minter role can initiate the transaction only.
     * @dev Initial contributors reward should be distributed before
     * initiating future distribution transaction. 
     * 
     * Steps:
     * 
     * 1. Check if initial contributors reward is distributed earlier
     * 2. Create & distribute shards to Future Data Owners and Clinics 
     * 
     * @param _productUID product NFT ID 
    */
    function createFutureShards(
        uint _productUID, 
        uint _futureContributorShare, 
        uint _clinicNegotiatedCredit, 
        address _clinicShardHolder
    ) 
        external 
        whenNotPaused
        checkRewardStatus(_futureContributorReward)
    {  
        require(hasRole(MINTER_ROLE, _msgSender()), "REJUVE: Must have minter role to mint shards");
        require(initialContributorReward, "REJUVE: Initial contributors not rewarded yet");
        _createFutureShards(_productUID, _futureContributorShare, _clinicNegotiatedCredit, _clinicShardHolder);
    }    

    /**
     * @notice Mint remaining shards if available & assign to rejuve 
     * @dev Caller should have minter role to execute function
     * @dev Initial & future contributors reward status must be true
    */ 
    function createRemainingShards(
        uint _productUID, 
        address _rejuveShardHolder
    ) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "REJUVE: Must have minter role to mint shards");
        require(initialContributorReward, "REJUVE: Initial contributors not rewarded yet");
        require(_futureContributorReward, "REJUVE: Future contributors not rewarded yet");
        require(_createRemainingShards(_productUID, _rejuveShardHolder), "REJUVE: No remaining shards available to mint");
    }  

//---------------------------------------------- PRIVATE ------------------------------------------------

    /**
     * @dev Private function to create future shards and their distribution 
     * 
     * Steps:
     * 
     * 1. Get all data hashes used in the product 
     * 2. Get sum of all data credits => total data credits
     * 3. Get data owner address 
     * 4. Get credit score against each data hash
     * 5. Calculate share for each contributor based on credit score
     * 7. Mint & Assign shards to each data contributor & clinic
    */
    function _createFutureShards(
        uint _productUID, 
        uint _futureContributorShare, 
        uint _clinicNegotiatedCredit, 
        address _clinicShardHolder
    ) private { 
        bytes[] memory productDataHashes = _getData(_productUID);
        uint totalCredits = _getTotalFutureCredits(_productUID);
        totalCredits = totalCredits + _clinicNegotiatedCredit;

        for(uint i = productNFT.getInitialDataLength(_productUID); i < productDataHashes.length; i++){

            address dataOwner = productNFT.getDataOwnerAddress(productDataHashes[i]);
            uint shardAmount = _calculateContributorShards(productNFT.getDataCredit(productDataHashes[i], _productUID), totalCredits, _futureContributorShare); 
            _mintShard(dataOwner, shardAmount); 
            futureDataOwners.push(dataOwner);
            futureDataOwnerShards.push(shardAmount);              
        }

        _calculateClinicShards(_clinicShardHolder, _clinicNegotiatedCredit, totalCredits, _futureContributorShare);
        _futureContributorReward = true;

        emit ShardDistributed(_productUID, futureDataOwners, futureDataOwnerShards);
    }

    /**
     * @dev Calculate & mint clinic shards as per negotiated weight (credit)
    */
    function _calculateClinicShards(
        address _clinicShardHolder, 
        uint _clinicNegotiatedCredit, 
        uint totalCredits, 
        uint _futureContributorShare
    ) private {
        uint clinicShardAmount = _calculateContributorShards(_clinicNegotiatedCredit, totalCredits, _futureContributorShare);        
        _mintShard(_clinicShardHolder, clinicShardAmount);
        futureDataOwners.push(_clinicShardHolder);
        futureDataOwnerShards.push(clinicShardAmount);
    }

    /**
     * @return uint sum of all future data credits 
    */ 
    function _getTotalFutureCredits(uint _productUID) private view returns(uint) {
        bytes[] memory productDataHashes = _getData(_productUID);
        uint _totalFutureCredits;

        for(uint i = productNFT.getInitialDataLength(_productUID); i < productDataHashes.length; i++){

            uint dataCredit = productNFT.getDataCredit(productDataHashes[i], _productUID); 
            _totalFutureCredits = _totalFutureCredits + dataCredit;

        }

        return _totalFutureCredits;
    }

    /**
     * @dev Create & assign remaining shards if available
     * - Check if total supply is less than target supply
     * - Mint remaining shard if condiition is true
    */
    function _createRemainingShards(
        uint _productUID, 
        address _rejuveShardHolder
    ) 
        private 
        returns(bool) 
    {
        bool sharded;
        uint remainingShards;

        if(_targetShardSupply > totalSupply()){
            remainingShards = _targetShardSupply - totalSupply();

            _mintShard(_rejuveShardHolder, remainingShards );
            sharded = true;
        }

        emit RemainingShardDistributed(_productUID, _rejuveShardHolder, remainingShards);
        return sharded;
    }  

}