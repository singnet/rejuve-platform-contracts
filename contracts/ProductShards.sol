// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductNFT.sol";

contract ProductShards is Ownable, Pausable, ERC1155 {

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

    // Shard amount of all future contributors 
    uint[] private _futureContributorShards;

    // Initial contributor reward status 
    bool private _initialRewardDistributed;

    // Future contributor reward status 
    bool private _futureRewardDistributed;

    // Mapping from productUID to its Shards config 
    mapping(uint => ShardConfig) private productToShardsConfig;

    // Mapping from productUID to Types array index
    mapping(uint => uint[]) private productToTypeIndexes;

    // Mapping from productUID to lock period
    mapping(uint => uint) private productToLockPeriod;

    //Mapping from Token Type ID to Product UID 
    mapping(uint => uint ) private typeToProduct;

    // Mapping from Type ID to state
    mapping(uint => string) private typeToState;

    /**
     * @dev Emitted when product shards are distributed to initial contributors
    */
    event InitialShardDistributed(uint productUID, address[] dataOwners, uint[] shardAmount);

    /**
     * @dev Emitted when product shards are distributed to future contributors
    */
    event FutureShardDistributed(uint productUID, address[] dataOwners, uint[] shardAmount);

    /**
     * @dev Emitted when remaining shards assigned to Rejuve - The Platform
    */
    event RemainingShardAssigned(uint productUID, address rejuve, uint shardAmount);

//------------------------------- Constructor -------------------------------------------

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
        address _rejuve 
    ) 
        external
        onlyOwner
        whenNotPaused
    {
       _distributeInitialShards(_productUID, _targetSupply, _labCredit, _lockPeriod, _initialPercent, _rejuvePercent, _lab, _rejuve);
    }

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
    function mintRemainingShards(uint _productUID, address _holder) 
        external 
        onlyOwner 
        whenNotPaused
    {
        _mintRemainingShards(_productUID, _holder);
    }

    /**
     * @dev Triggers stopped state.
     *
    */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    //------------------------------------ VIEWS -------------------------------------

    /**
     * @return mintedShardSupply of a given product UID
    */
    function totalShardSupply(uint _productUID) external view returns(uint) {
        return productToShardsConfig[_productUID].totalSupply;
    } 

    /**
     * @return targetSupply of a given product UID
    */
    function targetSupply(uint _productUID) external view returns(uint) {
        return productToShardsConfig[_productUID].targetSupply;
    }

    /**
     * A specific percentage out of total (targetSupply) is assigned to each category of participants,
     *  - Category 1: Initial data contributors 
     *  - Category 2: Future data contributors
     *  - Category 3: Rejuve - the Platform
     *
     * @return initialContributorPercent percentage for a given product
    */
    function initialPercent(uint _productUID) external view returns(uint8) {
        return productToShardsConfig[_productUID].initialPercent;
    }

    /**
     * @return futureContributorPercent - category 2
    */
    function futurePercent(uint _productUID) external view returns(uint8) {
        return productToShardsConfig[_productUID].futurePercent;
    }

    /**
     * @return rejuvePercent - category 3
    */
    function rejuvePercent(uint _productUID) external view returns(uint8) {
        return productToShardsConfig[_productUID].rejuvePercent;
    }

    /**
     * @return lockPeriod in which user cannot transfer 50% of his shards 
    */
    function lockPeriod(uint _productUID) external view returns(uint) {
        return productToShardsConfig[_productUID].lockPeriod;
    }

//---------------------------------------- PUBLIC ----------------------------------------------//

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {

        if (keccak256(bytes(typeToState[id])) == keccak256(bytes("LOCKED"))){ // check current time also if less than locking period   
            require(block.timestamp > productToLockPeriod[typeToProduct[id]], "REJUVE: Cannot sale 50% of shards before locking period"); 
            _transferShard(from, to, id, amount, data);
            
        }else {
            _transferShard(from, to, id, amount, data);
        }
      
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
        address _rejuve
    ) private {

        _setLockPeriod(_productUID, _lockPeriod);
        _configShard(_productUID, _targetSupply, productToLockPeriod[_productUID], _initialPercent, _rejuvePercent);
        _createTokenType(_productUID);
        _mintInitialShards(_productUID, _targetSupply, _initialPercent, _labCredit, _lab);
        _rejuveShare(_productUID, _targetSupply, _rejuve, _rejuvePercent);

        emit InitialShardDistributed(_productUID, _initialDataOwners, _initialDataOwnerShards);
        _initialRewardDistributed = true;
    }

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
    ) private {

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
        require(_initialRewardDistributed && _futureRewardDistributed, "REJUVE: Cannot mint before initial & future distribution ");
        ShardConfig storage config = productToShardsConfig[_productUID];
        uint amount = config.targetSupply - config.totalSupply;

        if(amount != 0){
            config.totalSupply = config.totalSupply + amount;
            uint[] memory amounts = _setAmount(amount); 
            for(uint i = 0; i < amounts.length; i++){
                _mint(_holder, productToTypeIndexes[_productUID][i], amounts[i], "0x00");
            }

            emit RemainingShardAssigned(_productUID, _holder, amount);
            
        }
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

        _preValidations(_targetSupply, _initialPercent);
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
    function _createTokenType(uint _productUID) private {

        string[] memory _tokenTypes = new string[](2);
        _tokenTypes[0] = "LOCKED";
        _tokenTypes[1] = "TRADED";

        for(uint8 i = 0; i < _tokenTypes.length; i++){
            _createType(_productUID, _tokenTypes[i]);
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
    ) 
        private
    {
        bytes[] memory productDataHashes = _getData(_productUID);
        uint totalCredits = _getTotalInitialCredits(_productUID);
        ShardConfig storage config = productToShardsConfig[_productUID];
        totalCredits = totalCredits + _labCredit;

        for(uint i = 0; i < _productNFT.getInitialDataLength(_productUID); i++){

            address dataOwner = _productNFT.getDataOwnerAddress(productDataHashes[i]);
            uint shardAmount = _shardsPerContributor(_productNFT.getDataCredit(productDataHashes[i], _productUID), totalCredits, _initialContributorShare, _targetSupply); 
            
            uint[] memory amounts = _setAmount(shardAmount); // 50% should go to locked type & 50% to traded
            _mintBatch(dataOwner, productToTypeIndexes[_productUID], amounts, "0x00" );

            config.totalSupply = config.totalSupply + shardAmount;  

            _initialDataOwners.push(dataOwner);
            _initialDataOwnerShards.push(shardAmount);
        }

        uint _labShardAmount = _labShards(_productUID, _lab, _labCredit, totalCredits, _initialContributorShare, _targetSupply);
        config.totalSupply = config.totalSupply + _labShardAmount;          
        _initialDataOwners.push(_lab);
        _initialDataOwnerShards.push(_labShardAmount);

    }

    /**
     * @dev Calculate Rejuve share in total target supply
     * @param _percent Rejuve share %  
    */
    function _rejuveShare(uint _productUID, uint _targetSupply, address _rejuve, uint _percent) private {

        ShardConfig storage config = productToShardsConfig[_productUID];
        uint amount = _availableShardAmount(_targetSupply, _percent);
        config.totalSupply = config.totalSupply + amount; 

        uint[] memory amounts = _setAmount(amount); 

        for(uint i = 0; i < amounts.length; i++){
            _mint(_rejuve, productToTypeIndexes[_productUID][i], amounts[i], "0x00");
        }
        
        _initialDataOwners.push(_rejuve);
        _initialDataOwnerShards.push(amount);
    }

    function _setLockPeriod(uint _productUID, uint _lockPeriod) private {
        require(_lockPeriod != 0, "REJUVE: Lock period cannot be zero");
        _lockPeriod = _lockPeriod + block.timestamp;
        productToLockPeriod[_productUID] = _lockPeriod;
    }

    function _transferShard(    
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private whenNotPaused {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);        
    }
//------------------------------------ Helpers---------------------------------------------//


    function _preValidations(
        uint _targetSupply,
        uint8 _initialPercent
 
    ) private pure {
        require(_targetSupply != 0, "REJUVE: Target supply can not be 0");
        require(_initialPercent != 0, "REJUVE: Initial contributors percent can not be 0");
    }

    /**
     * @dev Create types for given product UID
    */
    function _createType(uint _productUID, string memory _type) private {
        _types.push(_type);
        uint index = _types.length - 1;
        productToTypeIndexes[_productUID].push(index);
        typeToState[index] = _type;   
        typeToProduct[index] = _productUID; 
    }

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
    ) 
        private
        returns(uint)
    {

        uint amount = _shardsPerContributor(_labCredit, _totalCredits, _initialShare, _targetSupply);
        uint[] memory amounts = _setAmount(amount); 
         

        for(uint i = 0; i < amounts.length; i++){
            _mint(_lab, productToTypeIndexes[_productUID][i], amounts[i], "0x00");
        }   

        return amount;     
    }

    /**
     * @return uint sum of all initial data credits 
    */ 
    function _getTotalInitialCredits(uint _productUID) private view returns(uint) {
        bytes[] memory productDataHashes = _getData(_productUID);
        uint _totalInitialCredits;

        for(uint i = 0; i < productDataHashes.length; i++){

            uint dataCredit = _productNFT.getDataCredit(productDataHashes[i], _productUID); 
            _totalInitialCredits = _totalInitialCredits + dataCredit;

        }

        return _totalInitialCredits;
    }

    /**
     * @return bytes[] all data hashes used in the product 
    */ 
    function _getData(uint _productUID) private view returns(bytes[] memory) {
        bytes[] memory productData = _productNFT.getProductToData(_productUID);
        return productData;
    }

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
    ) 
        private
        pure
        returns(uint) 
    {
        uint _contributorShardsPercent = (100 * _creditScore) / _totalCreditScores;     
        uint total = _availableShardAmount(_targetSupply, _contributorShare);
        uint shardAmount = (total * _contributorShardsPercent) / 100; 
        return shardAmount;
    }

    // total available amount for percent (initital, final , lab etc)   
    function _availableShardAmount(uint _targetSupply,  uint _percent) private pure returns(uint) {
        uint availableAmount = (_targetSupply * _percent) / 100;
        return availableAmount;
    }

    /**
     * @dev 50% of shard amount should go to Locked Type 
     * Remaining shard to Traded type
    */
    function _setAmount(uint amount) private pure returns(uint[] memory) {

        // set both types shard amount
        uint[] memory amounts = new uint[](2);
        uint lockedAmount = _lockedAmount(amount); 
        amounts[0] = lockedAmount;  // locked amount at 0
        amount = amount - lockedAmount;
        amounts[1] = amount; // traded at 1    
        return amounts;
    }

    /**
     * @dev Calculate 50% shard amount
    */
    function _lockedAmount(uint _amount) private pure returns(uint) {     
        uint lockedAmount =  (_amount * 50)  / 100; // calculate 50% locked
        return lockedAmount;
    }

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