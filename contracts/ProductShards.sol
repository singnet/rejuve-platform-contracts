// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductNFT.sol";

/** @notice Contract module that provides product shards creation and 
 * allocation mechanisam. This module has 2 phases.
 * 
 * Phase 1:
 * 1. Shards Distribution to Initial data contributors including Lab
 * 2. Shards Distribution to Rejuve - The platoform
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

    constructor(string memory uri_, address productNFT_) ERC1155(uri_) {
        _productNFT = IProductNFT(productNFT_);
    }

    //---------------------------------  EXTERNAL --------------------------------------------//

    /**
     * @notice Shards creation and distribution to initial data contributors (including lab) and rejuve
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
        uint _productUID,
        uint _targetSupply,
        uint _labCredit,
        uint _lockPeriod,
        uint8 _initialPercent,
        uint8 _rejuvePercent,
        address _lab,
        address _rejuve,
        string[] memory _uris
    ) external onlyOwner whenNotPaused {
        _distributeInitialShards(
            _productUID,
            _targetSupply,
            _labCredit,
            _lockPeriod,
            _initialPercent,
            _rejuvePercent,
            _lab,
            _rejuve,
            _uris
        );
    }

    //------------------------------------ VIEWS -------------------------------------//

    /**
     * @return mintedShardSupply of a given product UID
     */
    function totalShardSupply(uint _productUID) external view returns (uint) {
        return productToShardsConfig[_productUID].totalSupply;
    }

    /**
     * @return targetSupply of a given product UID
     */
    function targetSupply(uint _productUID) external view returns (uint) {
        return productToShardsConfig[_productUID].targetSupply;
    }

    /**
     * @dev returns shards configuration info for a given productUID
     */
    function getShardsConfig(
        uint _productUID
    ) external view returns (uint, uint8, uint8, uint8) {
        return (
            productToShardsConfig[_productUID].lockPeriod,
            productToShardsConfig[_productUID].initialPercent,
            productToShardsConfig[_productUID].futurePercent,
            productToShardsConfig[_productUID].rejuvePercent
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
    function uri(uint256 _id) public view override returns (string memory) {
        return typeToURI[_id];
    }

    //---------------------------------------- INTERNAL ---------------------------------------------//

    /**
     * @dev Calculate shards Amount for individual data contributor
     *
     * Steps:
     * 1. Get individual percentage contribution using data credit score
     * 2. Get total shards available for this category
     * 3. Calculate shard amount as per percentage for individual data contributor
     */
    function _shardsPerContributor(
        uint _creditScore,
        uint _totalCreditScores,
        uint _contributorShare,
        uint _targetSupply
    ) internal pure returns (uint) {
        uint _contributorShardsPercent = (100 * _creditScore) /
            _totalCreditScores;
        //uint total = _availableShardAmount(_targetSupply, _contributorShare);
        uint total = (_targetSupply * _contributorShare) / 100;
        uint shardAmount = (total * _contributorShardsPercent) / 100;
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
     * @notice Shards creation and distribution to initial data contributors (including lab) and rejuve
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
     *      - @param _labCredit should be provided as input here as it was unknown when product NFT is created
     *      - As per credit, Lab will get proportional contribution shards like other initial data contributors
     *
     * 4. Create shards for Rejuve - The Platform
     *      - @param _rejuvePercent A specific percentage out of total (targetSupply) to Rejuve
     *
     * @param _productUID product NFT ID
     */
    function _distributeInitialShards(
        uint _productUID,
        uint _targetSupply,
        uint _labCredit,
        uint _lockPeriod,
        uint8 _initialPercent,
        uint8 _rejuvePercent,
        address _lab,
        address _rejuve,
        string[] memory _uris
    ) private {
        _setLockPeriod(_productUID, _lockPeriod);
        _configShard(
            _productUID,
            _targetSupply,
            productToLockPeriod[_productUID],
            _initialPercent,
            _rejuvePercent
        );
        _createTokenType(_productUID, _uris);
        _mintInitialShards(
            _productUID,
            _targetSupply,
            _initialPercent,
            _labCredit,
            _lab
        );
        _rejuveShare(_productUID, _targetSupply, _rejuve, _rejuvePercent);

        emit InitialShardDistributed(
            _productUID,
            _initialDataOwners,
            _initialDataOwnerShards
        );
        _initialRewardDistributed = true;
    }

    /**
     * @notice Set lock period for a given productUID
     * @param _lockPeriod days in seconds e.g for 2 days => 172,800 seconds
     */
    function _setLockPeriod(uint _productUID, uint _lockPeriod) private {
        require(_lockPeriod != 0, "REJUVE: Lock period cannot be zero");
        _lockPeriod = _lockPeriod + block.timestamp;
        productToLockPeriod[_productUID] = _lockPeriod;
    }

    /**
     * @dev Initial shard configuration for given productUID
     */
    function _configShard(
        uint _productUID,
        uint _targetSupply,
        uint _lockPeriod,
        uint8 _initialPercent,
        uint8 _rejuvePercent
    ) private {
        require(_targetSupply != 0, "REJUVE: Target supply cannot be 0");
        require(
            _initialPercent != 0,
            "REJUVE: Initial contributors percent cannot be 0"
        );

        ShardConfig storage config = productToShardsConfig[_productUID];
        config.productUID = _productUID;
        config.targetSupply = _targetSupply;
        config.lockPeriod = _lockPeriod;
        config.initialPercent = _initialPercent;
        config.rejuvePercent = _rejuvePercent;
    }

    /**
     * @dev 1155 token types - 2 types for each product (Locked & Traded)
     */
    function _createTokenType(uint _productUID, string[] memory _uris) private {
        string[] memory _tokenTypes = new string[](2);
        _tokenTypes[0] = "LOCKED";
        _tokenTypes[1] = "TRADED";

        for (uint8 i = 0; i < _tokenTypes.length; i++) {
            _types.push(_tokenTypes[i]);
            uint index = _types.length - 1;
            productToTypeIndexes[_productUID].push(index);
            typeToState[index] = _tokenTypes[i];
            typeToProduct[index] = _productUID;
            typeToURI[index] = _uris[i];
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
        uint _productUID,
        uint _targetSupply,
        uint _initialContributorShare,
        uint _labCredit,
        address _lab
    ) private {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            _productUID
        );
        uint totalCredits = _getTotalInitialCredits(_productUID);
        ShardConfig storage config = productToShardsConfig[_productUID];
        totalCredits = totalCredits + _labCredit;

        for (
            uint i = 0;
            i < _productNFT.getInitialDataLength(_productUID);
            i++
        ) {
            address dataOwner = _productNFT.getDataOwnerAddress(
                productDataHashes[i]
            );
            uint shardAmount = _shardsPerContributor(
                _productNFT.getDataCredit(productDataHashes[i], _productUID),
                totalCredits,
                _initialContributorShare,
                _targetSupply
            );

            uint[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(
                dataOwner,
                productToTypeIndexes[_productUID],
                amounts,
                "0x00"
            );

            config.totalSupply = config.totalSupply + shardAmount;

            _initialDataOwners.push(dataOwner);
            _initialDataOwnerShards.push(shardAmount);
        }

        uint _labShardAmount = _labShards(
            _productUID,
            _lab,
            _labCredit,
            totalCredits,
            _initialContributorShare,
            _targetSupply
        );
        config.totalSupply = config.totalSupply + _labShardAmount;
        _initialDataOwners.push(_lab);
        _initialDataOwnerShards.push(_labShardAmount);
    }

    /**
     * @dev Calculate Rejuve share in total target supply
     * @param _percent Rejuve share %
     */
    function _rejuveShare(
        uint _productUID,
        uint _targetSupply,
        address _rejuve,
        uint _percent
    ) private {
        ShardConfig storage config = productToShardsConfig[_productUID];
        uint amount = (_targetSupply * _percent) / 100;
        config.totalSupply = config.totalSupply + amount;

        uint[] memory amounts = _setAmount(amount);

        for (uint i = 0; i < amounts.length; i++) {
            _mint(
                _rejuve,
                productToTypeIndexes[_productUID][i],
                amounts[i],
                "0x00"
            );
        }

        _initialDataOwners.push(_rejuve);
        _initialDataOwnerShards.push(amount);
    }

    //------------------------------------ Helpers---------------------------------------------//

    /**
     * @dev Calculate lab shards as per its credit
     * @dev Lab will get shards in initial data contributor category
     */
    function _labShards(
        uint _productUID,
        address _lab,
        uint _labCredit,
        uint _totalCredits,
        uint _initialShare,
        uint _targetSupply
    ) private returns (uint) {
        uint amount = _shardsPerContributor(
            _labCredit,
            _totalCredits,
            _initialShare,
            _targetSupply
        );
        uint[] memory amounts = _setAmount(amount);

        for (uint i = 0; i < amounts.length; i++) {
            _mint(
                _lab,
                productToTypeIndexes[_productUID][i],
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
        uint _productUID
    ) private view returns (uint) {
        bytes[] memory productDataHashes = _productNFT.getProductToData(
            _productUID
        );
        uint _totalInitialCredits;

        for (uint i = 0; i < productDataHashes.length; i++) {
            uint dataCredit = _productNFT.getDataCredit(
                productDataHashes[i],
                _productUID
            );
            _totalInitialCredits = _totalInitialCredits + dataCredit;
        }

        return _totalInitialCredits;
    }
}
