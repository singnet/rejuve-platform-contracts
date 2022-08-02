// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IIdentityToken.sol";
import "./Interfaces/IDataManagement.sol";

/** @notice Contract module which provides product creation mechanism
 * that allow a registered identity to create a product. Also,
 * It allows product owner to link new data with existing product.
 * 
 * @dev contract deployer is the default owner. 
 * - Owner can call pause/unpause functions
*/

contract ProductNFT is Context, ERC721URIStorage, Ownable, Pausable {

    // Mapping from product to creator 
    mapping(uint => address) private productToCreator; 

    // Mapping from product UID to initial data array length
    mapping(uint => uint) private productToInitialLength;

    // Mapping from data hash to product UID to credit score
    mapping(bytes => mapping(uint => uint)) private dataToProductToCredit; 

    // Mapping from Product UID to data hashes 
    mapping(uint => bytes[]) private productToData; 

    IIdentityToken private _identityToken;
    IDataManagement private _dataMgt; 

    /**
     * @dev Emitted when a new product is created 
    */
    event ProductCreated(uint creatorID, uint productUID, string productURI, bytes[] datahashes, uint[] creditScore);

    /**
     * @dev Emitted when a new data hashes are linked with exisitng product NFT
    */
    event NewDataLinked(uint productUID, bytes[] dataHash, uint[] creditScore);

    constructor(
        string memory name_, 
        string memory symbol_, 
        IIdentityToken identityToken_, 
        IDataManagement dataMgt_
    ) 
        ERC721(name_, symbol_)
    {
        _identityToken = identityToken_;
        _dataMgt = dataMgt_;
    }

    /**
     * @dev Throws if called by unregistered user.
    */
    modifier ifRegisteredUser {
        require(_identityToken.ifRegistered(_msgSender()) == 1, "REJUVE: Not Registered");
        _;
    }
    
    /**
     * @dev Throws if called by user other than product creator
    */
    modifier onlyProductCreator (uint _productUID) {
        require(_msgSender() == productToCreator[_productUID], "REJUVE: Only Product Creator");
        _;
    }
//------------------------------ Step 5: Creating Product - Transaction by Lab / Product Creator ---------------------

    /**
     * @notice A lab can create a product NFT
     * - Caller is the default owner of the product
     * @dev Caller should be a registered identity (having identity token)
     * @param _productCreatorId caller identity token ID
     * @param _productUID product unique ID = next product UID 
     * @param _productURI product metadata
     * @param _dataHashes list of data hashes used in this product 
     * @param _creditScores AI assigned credit scores to each data hash
    */
    function createProduct(
        uint _productCreatorId, 
        uint _productUID, 
        string memory _productURI, 
        bytes[] memory _dataHashes, 
        uint[] memory _creditScores
    ) 
        external 
        whenNotPaused 
        ifRegisteredUser    
    {
        require(_msgSender() == _identityToken.ownerOf(_productCreatorId), "REJUVE: Caller is not owner of lab ID"); // if provided incorrect creator ID
        require(_dataHashes.length == _creditScores.length, "REJUVE: Not equal length");
        _createProduct(_productUID, _productURI, _dataHashes, _creditScores);

        emit ProductCreated(_productCreatorId, _productUID, _productURI, _dataHashes, _creditScores);
    }

    /**
     * @notice Link new data to existing product NFT
     * @dev only product owner (Lab) can call this function
    */
    function linkNewData(
        uint _productUID,
        bytes[] memory _newDataHashes, 
        uint[] memory _creditScores
    ) 
        external 
        whenNotPaused
        onlyProductCreator(_productUID)
    { 
        require(_newDataHashes.length == _creditScores.length, "REJUVE: Not equal length");
        require(!_linkData(_productUID, _newDataHashes, _creditScores), "REJUVE: Data Not Permitted");       
        
        emit NewDataLinked(_productUID, _newDataHashes, _creditScores); 
    }

//-------------------------------------- EXTERNAL VIEWS--------------------------------------------------

    /**
     * @notice returns all data (hashes) used in a specific product 
    */
    function getProductToData(uint _productUID) external view returns (bytes[] memory) {
        return productToData[_productUID];
    }

    /**
     * @notice returns credit score assigned to a data hash for a specific product
    */
    function getDataCredit(bytes memory _dHash, uint _productUID) external view returns(uint) {
        return dataToProductToCredit[_dHash][_productUID];
    }

    /**
     * @notice returns owner of given data 
    */
    function getDataOwnerAddress(bytes memory _dHash) external view returns(address) {     
        return _identityToken.ownerOf(_dataMgt.getDataOwnerId(_dHash));     
    }

    /**
     * @notice returns owner of given data 
    */
    function getInitialDataLength(uint _productUID) external view returns(uint) {
        return productToInitialLength[_productUID];
    }

    /**
     * @notice returns product creator address
    */
    function getProductCreator(uint _productUID) external view returns(address) {
        return productToCreator[_productUID];
    }

//---------------------------- -------- OWNER FUNCTIONS --------------------------------------------------

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

//-------------------------------------- Private Functions --------------------------------------------------

    /**
     * @notice Private function to create product NFT
     * - Link permitted data hashes with product UID  
     * - Use product UID as NFT token id
    */
    function _createProduct(
        uint _productUID, 
        string memory _productURI, 
        bytes[] memory _dataHashes, 
        uint[] memory _creditScores
    ) 
        private 
    {  
        require(!_linkData(_productUID, _dataHashes, _creditScores), "REJUVE: Data Not Permitted");
        _safeMint(_msgSender(), _productUID); 
        _setTokenURI(_productUID, _productURI);
        productToCreator[_productUID] = _msgSender();
        productToInitialLength[_productUID] =_dataHashes.length;
    }

    /**
     * @notice Private function to link data hashes with product UID
     * - check if all data hashes are permitted to be used in given product UID
     * - Assign credit scores (by AI) to all data hashes 
     * - Link product UID to all data hashes     
    */
    function _linkData(
        uint _productUID, 
        bytes [] memory _dataHashes, 
        uint[] memory _creditScores
    ) 
        private 
        returns(bool) 
    {

        bool notPermitted;
        for(uint i = 0; i < _dataHashes.length; i++) {

            if(_dataMgt.getPermissionStatus(_dataHashes[i], _productUID) == 1){ // 1 = permitted , 0 = not permitted
                dataToProductToCredit[_dataHashes[i]][_productUID] = _creditScores[i]; 
                productToData[_productUID].push(_dataHashes[i]);
            }
            else{
                notPermitted = true; // if any data hash inside data hash array is not permitted
                break;
            }

        } 

        return notPermitted;
    }

}