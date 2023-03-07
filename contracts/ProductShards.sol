// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductNFT.sol";

/** 
 * @title Product shards creation & allocation
 * @notice Contract module that provides product shards creation and 
 * allocation mechanisam. This module has 2 phases.
 * 
 * Phase 1:
 * 1. Shards Distribution to Initial data contributors including Lab
 * 2. Shards Distribution to Rejuve => The platoform
 *
 * Phase 2:
 * 1. Shards Distribution to Future data contributors e.g. clinics 

 * This contract implemented functionality for "Phase 1"
 * 
 * @dev contract deployer is the default owner. 
 * - Only Owner can call initial & future 
 * - Only Owner can call pause/unpause functions
*/
contract ProductShards is Ownable, Pausable, ERC1155 {

    //Product shards configuration
    struct ShardConfig {
        uint productUID;
        uint targetSupply;
        uint totalSupply;
        uint lockPeriod;
        uint8 initialPercent;
        uint8 rejuvePercent;
        uint8 futurePercent;
    }

    IProductNFT private _productNFT;

    // Two token types 1. Locked 2. Traded
    string[] private _types;

    // Addresses of all initial contributors
    address[] private _initialDataOwners;

    // Shard amount of all initial contributors
    uint[] private _initialDataOwnerShards;

    // Initial contributor reward status
    bool _initialRewardDistributed;

    // Mapping from productUID to its Shards config
    mapping(uint => ShardConfig) productToShardsConfig;

    // Mapping from productUID to Types array index
    mapping(uint => uint[]) productToTypeIndexes;

    // Mapping from productUID to lock period
    mapping(uint => uint) productToLockPeriod;

    //Mapping from Token Type ID to Product UID
    mapping(uint => uint) typeToProduct;

    // Mapping from Type ID to state
    mapping(uint => string) typeToState;

    //Mapping from TypeID to Type URI
    mapping(uint256 => string) typeToURI;

    /**
     * @dev Emitted when product shards are distributed to initial contributors
     */
    event InitialShardDistributed(
        uint productUID,
        address[] dataOwners,
        uint[] shardAmount
    );

    //------------------------------- Constructor -------------------------------------------//

    constructor(string memory uri_, address productNFT_) 
        ERC1155(uri_) 
    {
        _productNFT = IProductNFT(productNFT_);
    }

    //---------------------------------  EXTERNAL --------------------------------------------//

    /**
     * @notice Shards creation and distribution to initial data contributors (including lab) 
     * and Rejuve
     * @dev Rejuve (Who deploys the contract) can initiate the transaction
     *
     * Important:
     *
     * 1. Each product (NFT-ID) is connected to its shard configuration
     * 2. Every single product has two token types (1155) 1. Locked 2. Traded
     * 3. Create shards for initial data contributors including Lab.
     * 4. Create shards for Rejuve - The Platform
     *
     */
    function distributeInitialShards(
        uint productUID,
        uint targetSupply_,
        uint labCredit,
        uint lockPeriod,
        uint8 initialPercent,
        uint8 rejuvePercent,
        address lab,
        address rejuve,
        string[] memory uris
    ) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        _distributeInitialShards(
            productUID,
            targetSupply_,
            labCredit,
            lockPeriod,
            initialPercent,
            rejuvePercent,
            lab,
            rejuve,
            uris
        );
    }

    //------------------------------------ VIEWS -------------------------------------//

    /**
     * @return mintedShardSupply of a given product UID
     */
    function totalShardSupply(uint productUID) external view returns (uint) {
        return productToShardsConfig[productUID].totalSupply;
    }

    /**
     * @return targetSupply of a given product UID
     */
    function targetSupply(uint productUID) external view returns (uint) {
        return productToShardsConfig[productUID].targetSupply;
    }

    /**
     * @dev returns shards configuration info for a given productUID
     */
    function getShardsConfig(
        uint productUID
    ) external view returns (uint, uint8, uint8, uint8) {
        return (
            productToShardsConfig[productUID].lockPeriod,
            productToShardsConfig[productUID].initialPercent,
            productToShardsConfig[productUID].futurePercent,
            productToShardsConfig[productUID].rejuvePercent
        );
    }

    /**
     * @dev returns type IDs for a given productUID
     */
    function getProductIDs(
        uint productUID
    ) external view returns (uint[] memory) {
        return productToTypeIndexes[productUID];
    }

    //--------------------------------------- PUBLIC ------------------------------------------------//

    /**
     * @dev returns unique URI for unique ID type (locked, traded)
     */
    function uri(uint256 id) public view override returns (string memory) {
        return typeToURI[id];
    }

    //---------------------------------------- INTERNAL --------------------------------//

    /**
     * @dev Calculate shards Amount for individual data contributor
     *
     * Steps:
     * 1. Get individual percentage contribution using data credit score
     * 2. Get total shards available for this category
     * 3. Calculate shard amount as per percentage for individual data contributor
     */
    function _shardsPerContributor(
        uint creditScore,
        uint totalCreditScores,
        uint contributorShare,
        uint targetSupply_
    ) internal pure returns (uint) {
        uint contributorShardsPercent = (100 * creditScore) /
            totalCreditScores;
        uint total = (targetSupply_ * contributorShare) / 100;
        uint shardAmount = (total * contributorShardsPercent) / 100;
        return shardAmount;
    }

    /**
     * @dev 50% of shard amount should go to Locked Type
     * Remaining shard to Traded type
     */
    function _setAmount(uint amount) internal pure returns (uint[] memory) {
        // set both types shard amount
        uint[] memory amounts = new uint[](2);
        uint lockedAmount = (amount * 50) / 100; // calculate 50% locked
        amounts[0] = lockedAmount; // locked amount at 0
        amount = amount - lockedAmount;
        amounts[1] = amount; // traded at 1
        return amounts;
    }

    //---------------------------------------- PRIVATE ---------------------------------------------//

    /**
     * @notice Shards creation and distribution to initial data contributors (including lab) 
     * and Rejuve
     * @dev Rejuve (Who deploys the contract) can initiate the transaction
     *
     * Steps:
     *
     * 1. Configure shards for given product UID
     * 2. TokenTypes Create Two token types inside 1155 for each product
     *       - Array indexes are taken as IDs
     *       - Locked = 0 , Traded = 1
     *
     * 3. Create shards for initial data contributors including Lab.
     *      - @param labCredit should be provided as input here as it was unknown 
     *          when product NFT is created
     *      - As per credit, Lab will get proportional contribution shards like 
     *          other initial data contributors
     *
     * 4. Create shards for Rejuve - The Platform
     *      - @param rejuvePercent A specific percentage out of total (targetSupply) to 
     *      Rejuve
     *
     * @param productUID product NFT ID
    */
    function _distributeInitialShards(
        uint productUID,
        uint targetSupply_,
        uint labCredit,
        uint lockPeriod,
        uint8 initialPercent,
        uint8 rejuvePercent,
        address lab,
        address rejuve,
        string[] memory uris
    ) private {
        _setLockPeriod(productUID, lockPeriod);
        _configShard(
            productUID,
            targetSupply_,
            productToLockPeriod[productUID],
            initialPercent,
            rejuvePercent
        );
        _createTokenType(productUID, uris);
        _mintInitialShards(
            productUID,
            targetSupply_,
            initialPercent,
            labCredit,
            lab
        );
        _rejuveShare(productUID, targetSupply_, rejuve, rejuvePercent);

        emit InitialShardDistributed(
            productUID,
            _initialDataOwners,
            _initialDataOwnerShards
        );
        _initialRewardDistributed = true;
    }

    /**
     * @notice Set lock period for a given productUID
     * @param lockPeriod days in seconds e.g for 2 days => 172,800 seconds
     */
    function _setLockPeriod(uint productUID, uint lockPeriod) private {
        require(lockPeriod != 0, "REJUVE: Lock period cannot be zero");
        lockPeriod = lockPeriod + block.timestamp;
        productToLockPeriod[productUID] = lockPeriod;
    }

    /**
     * @dev Initial shard configuration for given productUID
     */
    function _configShard(
        uint productUID,
        uint targetSupply_,
        uint lockPeriod,
        uint8 initialPercent,
        uint8 rejuvePercent
    ) private {
        require(targetSupply_ != 0, "REJUVE: Target supply cannot be 0");
        require(
            initialPercent != 0,
            "REJUVE: Initial contributors percent cannot be 0"
        );

        ShardConfig storage config = productToShardsConfig[productUID];
        config.productUID = productUID;
        config.targetSupply = targetSupply_;
        config.lockPeriod = lockPeriod;
        config.initialPercent = initialPercent;
        config.rejuvePercent = rejuvePercent;
    }

    /**
     * @dev 1155 token types - 2 types for each product (Locked & Traded)
     */
    function _createTokenType(uint productUID, string[] memory uris) private {
        string[] memory tokenTypes = new string[](2);
        tokenTypes[0] = "LOCKED";
        tokenTypes[1] = "TRADED";

        for (uint8 i = 0; i < tokenTypes.length; i++) {
            _types.push(tokenTypes[i]);
            uint index = _types.length - 1;
            productToTypeIndexes[productUID].push(index);
            typeToState[index] = tokenTypes[i];
            typeToProduct[index] = productUID;
            typeToURI[index] = uris[i];
        }
    }

    /**
     * @dev Private function to create shards
     *
     * Steps:
     *
     * 1. Get all data hashes used in a specific product
     * 2. Get sum of all data credits => totalCredits
     * 3. Add lab credit to total credits
     *
     * 4. Calculate shards for every single data contributor,
     *
     *  - Get data owner address
     *  - Get credit score against his data hash
     *  - Calculate shard amount for each contributor based on credit score
     *  - Take 50% of calculated shard amount
     *  - Mint 50% shards for Type 0 (Locked) & 50% for Type 1 (Traded) using BatchMint 1155
     *
     * 5. Calculate & mint shards for lab as per labCredit
     *  - Lab will get proprotional contribution from initial percent category
     */
    function _mintInitialShards(
        uint productUID,
        uint targetSupply_,
        uint initialContributorShare,
        uint labCredit,
        address lab
    ) private {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            productUID
        );
        uint totalCredits = _getTotalInitialCredits(productUID);
        ShardConfig storage config = productToShardsConfig[productUID];
        totalCredits = totalCredits + labCredit;

        for (
            uint i = 0;
            i < _productNFT.getInitialDataLength(productUID);
            i++
        ) {
            address dataOwner = _productNFT.getDataOwnerAddress(
                productDataHashes[i]
            );
            uint shardAmount = _shardsPerContributor(
                _productNFT.getDataCredit(productDataHashes[i], productUID),
                totalCredits,
                initialContributorShare,
                targetSupply_
            );

            uint[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(
                dataOwner,
                productToTypeIndexes[productUID],
                amounts,
                "0x00"
            );

            config.totalSupply = config.totalSupply + shardAmount;

            _initialDataOwners.push(dataOwner);
            _initialDataOwnerShards.push(shardAmount);
        }

        uint _labShardAmount = _labShards(
            productUID,
            lab,
            labCredit,
            totalCredits,
            initialContributorShare,
            targetSupply_
        );
        config.totalSupply = config.totalSupply + _labShardAmount;
        _initialDataOwners.push(lab);
        _initialDataOwnerShards.push(_labShardAmount);
    }

    /**
     * @dev Calculate Rejuve share in total target supply
     * @param percent Rejuve share %
     */
    function _rejuveShare(
        uint productUID,
        uint targetSupply_,
        address rejuve,
        uint percent
    ) private {
        ShardConfig storage config = productToShardsConfig[productUID];
        uint amount = (targetSupply_ * percent) / 100;
        config.totalSupply = config.totalSupply + amount;

        uint[] memory amounts = _setAmount(amount);

        for (uint i = 0; i < amounts.length; i++) {
            _mint(
                rejuve,
                productToTypeIndexes[productUID][i],
                amounts[i],
                "0x00"
            );
        }

        _initialDataOwners.push(rejuve);
        _initialDataOwnerShards.push(amount);
    }

    //------------------------------------ Helpers---------------------------------------------//

    /**
     * @dev Calculate lab shards as per its credit
     * @dev Lab will get shards in initial data contributor category
     */
    function _labShards(
        uint productUID,
        address lab,
        uint labCredit,
        uint totalCredits,
        uint initialShare,
        uint targetSupply_
    ) private returns (uint) {
        uint amount = _shardsPerContributor(
            labCredit,
            totalCredits,
            initialShare,
            targetSupply_
        );
        uint[] memory amounts = _setAmount(amount);

        for (uint i = 0; i < amounts.length; i++) {
            _mint(
                lab,
                productToTypeIndexes[productUID][i],
                amounts[i],
                "0x00"
            );
        }

        return amount;
    }

    /**
     * @return uint sum of all initial data credits
     */
    function _getTotalInitialCredits(
        uint productUID
    ) private view returns (uint) {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            productUID
        );

        uint totalInitialCredits;

        for (uint i = 0; i < productDataHashes.length; i++) {
            uint dataCredit = _productNFT.getDataCredit(
                productDataHashes[i],
                productUID
            );
            totalInitialCredits = totalInitialCredits + dataCredit;
        }

        return totalInitialCredits;
    }
}
