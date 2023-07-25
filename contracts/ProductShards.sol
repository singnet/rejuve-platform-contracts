// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductNFT.sol";
import "hardhat/console.sol";

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

    // Product shards configuration
    struct ShardConfig {
        uint256 productUID;
        uint256 targetSupply;
        uint256 totalSupply;
        uint256 lockPeriod;
        uint8 initialPercent;
        uint8 rejuvePercent;
        uint8 futurePercent;
    }

    IProductNFT private _productNFT;

    // Two token types for each product 1. Locked 2. Tradable
    bytes32[] private _types;

    // Mapping from productUID to initial data contributors including (Lab & Rejuve)
    mapping(uint256 => address[]) private _initialContributors;

    // Mapping from productUID to Shard amount of all initial contributors
    mapping(uint256 => uint256[]) private _initialContributorShards;

    // Mapping from productUID to initialShardsDistribution status
    mapping(uint256 => bool) private _initialDistributionStatus;

    // Mapping from productUID to its Shards config
    mapping(uint256 => ShardConfig) productToShardsConfig;

    // Mapping from productUID to Types array index
    mapping(uint256 => uint256[]) productToTypeIndexes;

    // Mapping from productUID to lock period
    mapping(uint256 => uint256) productToLockPeriod;

    //Mapping from Token Type ID to Product UID
    mapping(uint256 => uint256) typeToProduct;

    // Mapping from Type ID to state
    mapping(uint256 => bytes32) typeToState;

    //Mapping from TypeID to Type URI
    mapping(uint256 => string) typeToURI;

    /**
     * @dev Emitted when product shards are distributed to initial contributors
     */
    event InitialShardDistributed(
        uint256 productUID,
        address[] initialContributors,
        uint256[] shardAmount
    );

    //------------------------------- Constructor --------------------//

    constructor(string memory uri_, address productNFT_) 
        ERC1155(uri_) 
    {
        _productNFT = IProductNFT(productNFT_);
    }

    //---------------------------------  EXTERNAL --------------------//

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
        uint256 productUID,
        uint256 targetSupply_,
        uint256 labCredit,
        uint256 lockPeriod,
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
        require(
            !_initialDistributionStatus[productUID], 
            "REJUVE: Initial shards distributed already"
        );
        _preValidate(
            targetSupply_,
            labCredit,
            lockPeriod,
            initialPercent,
            rejuvePercent,
            lab,
            rejuve,
            uris
        );
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

    //--------------------- VIEWS --------------------------------//

    /**
     * @return mintedShardSupply of a given product UID
     */
    function totalShardSupply(uint256 productUID) external view returns (uint256) {
        return productToShardsConfig[productUID].totalSupply;
    }

    /**
     * @return targetSupply of a given product UID
     */
    function targetSupply(uint256 productUID) external view returns (uint256) {
        return productToShardsConfig[productUID].targetSupply;
    }

    /**
     * @dev returns shards configuration info for a given productUID
     */
    function getShardsConfig(
        uint256 productUID
    ) external view returns (uint256, uint8, uint8, uint8) {
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
        uint256 productUID
    ) external view returns (uint256[] memory) {
        return productToTypeIndexes[productUID];
    }

    /**
     * @return Status of initial shards distribution
    */
    function getInitialDistributionStatus(
        uint256 productUID
    ) external view returns (bool) {
        return _initialDistributionStatus[productUID];
    }

    /**
     * @return Initial contributors (Data owners, Lab and Rejuve) addresses 
    */
    function getInitialContributors(
        uint256 productUID
    ) external view returns(address[] memory){
        return _initialContributors[productUID];
    }

    /**
     * @return Initial contributors (Data owners, Lab and Rejuve) shards amount 
    */
    function getInitialContributorShards(
        uint256 productUID
    ) external view returns(uint256[] memory){
        return _initialContributorShards[productUID];
    }

    //---------------------- PUBLIC -------------------------------------//

    /**
     * @dev returns unique URI for unique ID type (locked, traded)
     */
    function uri(uint256 id) public view override returns (string memory) {
        return typeToURI[id];
    }

    //------------------------ INTERNAL --------------------------------//

    /**
     * @dev Calculate shards Amount for individual data contributor
     *
     * Steps:
     * 1. Get individual percentage contribution using data credit score
     * 2. Get total shards available for this category
     * 3. Calculate shard amount as per percentage for individual data contributor
     */
    function _shardsPerContributor(
        uint256 creditScore,
        uint256 totalCreditScores,
        uint256 contributorShare,
        uint256 targetSupply_
    ) internal pure returns (uint) {
        uint256 contributorShardsPercent = (100 * creditScore) /
            totalCreditScores;
        uint256 total = (targetSupply_ * contributorShare) / 100;
        uint256 shardAmount = (total * contributorShardsPercent) / 100;
        return shardAmount;
    }

    /**
     * @dev 50% of shard amount should go to Locked Type
     * Remaining shard to Traded type
     */
    function _setAmount(uint256 amount) internal pure returns (uint256[] memory) {
        // set both types shard amount
        uint256[] memory amounts = new uint256[](2);
        uint256 lockedAmount = (amount * 50) / 100; // calculate 50% locked
        amounts[0] = lockedAmount; // locked amount at 0
        amount = amount - lockedAmount;
        amounts[1] = amount; // traded at 1
        return amounts;
    }

    //----------------------------- PRIVATE -----------------------------//

    /**
     * @dev Checking input values 
    */
    function _preValidate(
        uint256 targetSupply_,
        uint256 labCredit,
        uint256 lockPeriod,
        uint8 initialPercent,
        uint8 rejuvePercent,
        address lab,
        address rejuve,
        string[] memory uris
    ) 
        private 
        pure
    {
        require(targetSupply_ > 0, "REJUVE: Target supply cannot be zero");
        require(labCredit > 0, "REJUVE: Lab credit cannot be zero");
        require(lockPeriod > 0, "REJUVE: Lock period cannot be zero");
        require(initialPercent > 0, "REJUVE: Initial percent cannot be zero");
        require(rejuvePercent > 0, "REJUVE: Rejuve percent cannot be zero");
        require(lab !=  address(0), "REJUVE: Lab address cannot be zero");
        require(rejuve !=  address(0), "REJUVE: Rejuve address cannot be zero");
        require(uris.length > 0, "REJUVE: URIs length cannot be zero");
    }

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
        uint256 productUID,
        uint256 targetSupply_,
        uint256 labCredit,
        uint256 lockPeriod,
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
            initialPercent,
            labCredit,
            lab
        );
        _rejuveShare(productUID, targetSupply_, rejuvePercent, rejuve); 

        emit InitialShardDistributed(
            productUID,
            _initialContributors[productUID],
            _initialContributorShards[productUID]
        );

        _initialDistributionStatus[productUID] = true;
    }

    /**
     * @notice Set lock period for a given productUID
     * @param lockPeriod days in seconds e.g for 2 days => 172,800 seconds
     */
    function _setLockPeriod(uint256 productUID, uint256 lockPeriod) private {
        lockPeriod = lockPeriod + block.timestamp;
        productToLockPeriod[productUID] = lockPeriod;
    }

    /**
     * @dev Initial shard configuration for given productUID
     */
    function _configShard(
        uint256 productUID,
        uint256 targetSupply_,
        uint256 lockPeriod,
        uint8 initialPercent,
        uint8 rejuvePercent
    ) private {
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
    function _createTokenType(uint256 productUID, string[] memory uris) private {
        bytes32[] memory tokenTypes = new bytes32[](2);
        tokenTypes[0] = "LOCKED";
        tokenTypes[1] = "TRADED";

        for (uint8 i = 0; i < tokenTypes.length; i++) {
            _types.push(tokenTypes[i]);
            uint256 index = _types.length - 1;
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
        uint256 productUID,
        uint256 initialContributorShare,
        uint256 labCredit,
        address lab
    ) private {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            productUID
        );
        uint256 totalCredits = _getTotalInitialCredits(productUID);
        ShardConfig storage config = productToShardsConfig[productUID];
        totalCredits = totalCredits + labCredit;
        uint256 initialDataLength = _productNFT.getInitialDataLength(productUID);

        for (
            uint256 i = 0;
            i < initialDataLength;
            i++
        ) {
            address dataOwner = _productNFT.getDataOwnerAddress(
                productDataHashes[i]
            );
            uint256 shardAmount = _shardsPerContributor(
                _productNFT.getDataCredit(productDataHashes[i], productUID),
                totalCredits,
                initialContributorShare,
                config.targetSupply
            );

            uint256[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(
                dataOwner,
                productToTypeIndexes[productUID],
                amounts,
                "0x00"
            );

            config.totalSupply = config.totalSupply + shardAmount;
            _initialContributors[productUID].push(dataOwner);
            _initialContributorShards[productUID].push(shardAmount);
        }

        uint256 labShardAmount = _labShards(
            productUID,
            labCredit,
            totalCredits,
            initialContributorShare,
            config.targetSupply,
            lab
        );
        config.totalSupply = config.totalSupply + labShardAmount;
        _initialContributors[productUID].push(lab);
        _initialContributorShards[productUID].push(labShardAmount);
    }

    /**
     * @dev Calculate Rejuve share in total target supply
     * @param percent Rejuve share %
     */
    function _rejuveShare(
        uint256 productUID,
        uint256 targetSupply_,
        uint256 percent,
        address rejuve
    ) private {
        ShardConfig storage config = productToShardsConfig[productUID];
        uint256 amount = (targetSupply_ * percent) / 100;
        config.totalSupply = config.totalSupply + amount;
        uint256[] memory amounts = _setAmount(amount);
        _initialContributors[productUID].push(rejuve);
        _initialContributorShards[productUID].push(amount);

        _mintBatch(rejuve, productToTypeIndexes[productUID], amounts, "0x00");
    }

    //------------------------------- Helpers-----------------------------//

    /**
     * @dev Calculate lab shards as per its credit
     * @dev Lab will get shards in initial data contributor category
     */
    function _labShards(
        uint256 productUID,
        uint256 labCredit,
        uint256 totalCredits,
        uint256 initialShare,
        uint256 targetSupply_,
        address lab
    ) private returns (uint256) {
        uint256 amount = _shardsPerContributor(
            labCredit,
            totalCredits,
            initialShare,
            targetSupply_
        );
        uint256[] memory amounts = _setAmount(amount);
        _mintBatch(lab, productToTypeIndexes[productUID], amounts, "0x00");
  
        return amount;
    }

    /**
     * @return uint sum of all initial data credits
     */
    function _getTotalInitialCredits(
        uint256 productUID
    ) private view returns (uint256) {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            productUID
        );
        uint256 totalInitialCredits;
        uint256 productHashesLength = productDataHashes.length;

        for (uint256 i = 0; i < productHashesLength; i++) {
            uint256 dataCredit = _productNFT.getDataCredit(
                productDataHashes[i],
                productUID
            );
            totalInitialCredits = totalInitialCredits + dataCredit;
        }

        return totalInitialCredits;
    }
}