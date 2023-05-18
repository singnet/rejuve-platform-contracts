// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;
import "./ProductShards.sol";

/** 
 * @title Future shards creation & allocation
 * @notice Contract module that provides product shards creation to future contributors.
 *  this is phase 2 of Product shards contract.
 *
 * Phase 2:
 * 1. Shards Distribution to Future data contributors e.g. clinics
 *
 * @dev contract deployer is the default owner.
 * - Only Owner can call initial & future shards allocation functions
 * - Only Owner can call pause/unpause functions
*/
contract FutureShards is ProductShards {

    // Mapping from productUID to initial data contributors including (Lab & Rejuve)
    mapping(uint256 => address[]) private _futureContributors;

    // Mapping from productUID to Shard amount of all initial contributors
    mapping(uint256 => uint256[]) private _futureContributorShards;

    // Mapping from productUID to futureShardsDistribution status
    mapping(uint256 => bool) private _futureDistributionStatus;

    /**
     * @dev Emitted when product shards are distributed to future contributors
     */
    event FutureShardDistributed(
        uint256 productUID,
        address[] dataOwners,
        uint256[] shardAmount
    );

    //------------------------------- Constructor ------------------------------//

    constructor(string memory uri, address productNFT) 
        ProductShards(uri, productNFT) 
    {}

    //---------------------------------  EXTERNAL ------------------------------//

    /**
     * @notice Shards creation and distribution to future data contributors 
     * e.g. clinics or any other entity
     * @dev Rejuve (Who deploys the contract) can initiate the transaction
     *
     * Important:
     *
     * 1. @param futurePercent - share % assigned to future contributors category 
     * out of total target
     * 2. @param credits - negotiated weights
     * 3. @param futureContributors - addresses of future contributors that are getting shards
     */
    function distributeFutureShards(
        uint256 productUID,
        uint8 futurePercent,
        uint256[] memory credits,
        address[] memory futureContributors
    ) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        require(
            !_futureDistributionStatus[productUID], 
            "REJUVE: Future shards distributed already"
        );
        require(futurePercent > 0, "REJUVE: Future percent cannot be zero");
        ShardConfig memory confg = productToShardsConfig[productUID];
        uint256 remainingPercent = 100 - (confg.initialPercent + confg.rejuvePercent);
        require(
            futurePercent <= remainingPercent, 
            "REJUVE: Future percent exceeds available limit"
        );
        require(
            futureContributors.length == credits.length,
            "REJUVE: Not equal length"
        );

        _distributeFutureShards(
            productUID,
            futurePercent,
            credits,
            futureContributors
        );
    }

    //---------------------------- VIEWS --------------------------------//

    /**
     * @return Status of future shards distribution
    */
    function getFutureDistributionStatus(
        uint256 productUID
    ) external view returns (bool) {
        return _futureDistributionStatus[productUID];
    }

    /**
     * @return Future contributors (Clinics and others if any) addresses 
    */
    function getFutureContributors(
        uint256 productUID
    ) external view returns(address[] memory){
        return _futureContributors[productUID];
    }

    /**
     * @return Future contributors (Data owners, Lab and Rejuve) shards amount 
    */
    function getFutureContributorShards(
        uint256 productUID
    ) external view returns(uint256[] memory){
        return _futureContributorShards[productUID];
    }
    
    //-----------------------------PRIVATE -----------------------------//

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
        uint256 productUID,
        uint8 futurePercent,
        uint256[] memory credits,
        address[] memory futureContributors
    ) private {
        ShardConfig storage config = productToShardsConfig[productUID];
        config.futurePercent = futurePercent;
        uint256 totalCredits = _totalFutureCredits(credits);
        uint256 totalFutureContributors = futureContributors.length;
       
        for (uint256 i = 0; i < totalFutureContributors; i++) {
            address futureContributor = futureContributors[i];
            uint256 shardAmount = _shardsPerContributor(
                credits[i],
                totalCredits,
                futurePercent,
                config.targetSupply
            );
            uint256[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(
                futureContributor,
                productToTypeIndexes[productUID],
                amounts,
                "0x00"
            );

            config.totalSupply = config.totalSupply + shardAmount;
            _futureContributors[productUID].push(futureContributor);
            _futureContributorShards[productUID].push(shardAmount);
        }

        emit FutureShardDistributed(
            productUID,
            _futureContributors[productUID],
            _futureContributorShards[productUID]
        );

        _futureDistributionStatus[productUID] = true;
    }

    //------------------------------------ Helpers------------------------//

    /**
     * @dev Calculate total future credits
     */
    function _totalFutureCredits(
        uint256[] memory credits
    ) private pure returns (uint) {
        uint256 creditsLength = credits.length;
        uint256 totalCredits;
        for (uint256 i = 0; i < creditsLength; i++) {
            totalCredits = totalCredits + credits[i];
        }
        return totalCredits;
    }
}
