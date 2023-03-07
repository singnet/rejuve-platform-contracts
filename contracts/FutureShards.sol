// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
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

    // Future contributor reward status
    bool private _futureRewardDistributed;

    // Shard amount of all future contributors
    uint[] private _futureContributorShards;

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
     * 1. @param futurePercent share % assigned to future contributors category 
     * out of total target
     * 2. @param credits negotiated weights
     * 3. @param futureContributors addresses of future contributors that are getting shards
     */
    function distributeFutureShards(
        uint productUID,
        uint8 futurePercent,
        uint[] memory credits,
        address[] memory futureContributors
    ) external onlyOwner whenNotPaused {
        _distributeFutureShards(
            productUID,
            futurePercent,
            credits,
            futureContributors
        );
    }

    //---------------------------------------- PRIVATE -------------------------//

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
        uint productUID,
        uint8 futurePercent,
        uint[] memory credits,
        address[] memory futureContributors
    ) private {
        require(
            futureContributors.length == credits.length,
            "REJUVE: Not equal length"
        );
        require(
            futurePercent != 0,
            "REJUVE: Future percentage share cannot be zero"
        );

        ShardConfig storage config = productToShardsConfig[productUID];
        config.futurePercent = futurePercent;
        uint totalCredits = _totalFutureCredits(credits);

        for (uint i = 0; i < futureContributors.length; i++) {
            uint shardAmount = _shardsPerContributor(
                credits[i],
                totalCredits,
                futurePercent,
                config.targetSupply
            );
            uint[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(
                futureContributors[i],
                productToTypeIndexes[productUID],
                amounts,
                "0x00"
            );

            config.totalSupply = config.totalSupply + shardAmount;
            _futureContributorShards.push(shardAmount);
        }

        emit FutureShardDistributed(
            productUID,
            futureContributors,
            _futureContributorShards
        );
        _futureRewardDistributed = true;
    }

    //------------------------------------ Helpers------------------------//

    /**
     * @dev Calculate total future credits
     */
    function _totalFutureCredits(
        uint[] memory credits
    ) private pure returns (uint) {
        uint totalCredits;
        for (uint i = 0; i < credits.length; i++) {
            totalCredits = totalCredits + credits[i];
        }
        return totalCredits;
    }
}
