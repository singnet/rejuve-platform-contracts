// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./Done/DataManagement.sol";

/** @dev Contract module which provides product creation mechanism. 
 *  that allow a registered identity to create a product.  
*/

contract ProductNFT is DataManagement {

    // Mapping from data hash to product UID to credit score
    mapping(bytes32 => mapping(uint => uint)) dataToProductToCredit; 

    // Mapping from Product UID to data hashes 
    mapping(uint => bytes32[]) productToData; 

    /**
     * @dev Emitted when a new product is created 
    */
    event ProductCreated(uint creatorID, uint productUID);

    constructor(string memory name_, string memory symbol_) 
        DataManagement(name_, symbol_)
    {}
    
//------------------------------ Step 5: Creating Product - Transaction by Lab / Rejuve ---------------------

    /**
     * @notice A lab can create a product NFT
     * @dev Caller should have a registered identity 
     * @param _productCreatorId caller identity token ID
     * @param _productUID product unique ID = next product UID 
     * @param _dataHashes list of data hashes used in this product 
     * @param _creditScores AI assigned credit scores to each data hash
    */
    function createProduct(uint _productCreatorId, uint _productUID, bytes32[] memory _dataHashes, uint[] memory _creditScores) external ifRegistered {
        require(msg.sender == ownerOf(_productCreatorId), "REJUVE: Caller is not owner of lab ID");
        require(_dataHashes.length == _creditScores.length, "REJUVE: Not equal length");
        // add into owner to token id mapping when creating shards
        _createProduct(_productUID, _dataHashes, _creditScores);

        emit ProductCreated(_productCreatorId, _productUID); 
    }

    /**
     * @notice Link new data to existing product
     * @dev only product owner (Lab/rejuve) can call
     * Experimental
    */
    function linkNewData(uint _productUID, bytes32 _dataHash, uint _creditScore) external { // admin not added yet
        require(dataToProductPermission[_dataHash][_productUID] == PermissionState.Permitted, "REJUVE: Data Not Permitted");
        productToData[_productUID].push(_dataHash);      
        dataToProductToCredit[_dataHash][_productUID] = _creditScore;  
    }
    
//-------------------------------------- VIEWS--------------------------------------------------

    /**
     * @notice returns all data (hashes) used in a specific product 
    */
    function getProductToData(uint _productUID) external view returns (bytes32[] memory) {
        return productToData[_productUID];
    }

    /**
     * @notice returns credit score assigned to a data hash for a specific product
    */
    function getDataCredit(bytes32 _dHash, uint _productUID) external view returns(uint) {
        return dataToProductToCredit[_dHash][_productUID];
    }

    /**
     * @notice returns owner of given data 
    */
    function getDataOwnerAddress(bytes32 _dHash) external view returns(address) {     
        return ownerOf(dataToOwner[_dHash]);     
    }

//-------------------------------------- Private Functions --------------------------------------------------

    /**
     * @notice Private function to create product NFT
     * @dev check if all data hashes are permitted to be used in given product UID
     * @dev Assign credit scores (by AI) to all data hashes 
     * @dev Link product UID to all data hashes     
     * @dev Use product UID as token id
    */
    function _createProduct(uint _productUID, bytes32[] memory _dataHashes, uint[] memory _creditScores) private {

        for(uint i = 0; i < _dataHashes.length; i++) {
            if(dataToProductPermission[_dataHashes[i]][_productUID] == PermissionState.Permitted){ 
                dataToProductToCredit[_dataHashes[i]][_productUID] = _creditScores[i]; 
                productToData[_productUID].push(_dataHashes[i]);
            }
            else{break;}
        } 

        _safeMint(msg.sender, _productUID); 
    }

}