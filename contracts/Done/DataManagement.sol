// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./IdentityToken.sol";

/** @dev Contract module which provides data submission, permission
 *  request and granting mechanism.  
 *  It allows a lab to request specific data access.
 *  Data owner can grant permission to access the data.
*/

contract DataManagement is IdentityToken {

    enum PermissionState { NotPermitted, Permitted, Rejected } // what's next if data owner rejects data usage request 

    mapping(bytes32 => bytes32[]) dataToPermissions; // test
    mapping(bytes32 => uint) dataToOwner; // dataHash to identity token - data to owner 
    mapping(uint => bytes32[]) ownerToPermissions; // tokenId(owner) to permission array
    mapping(uint => uint[]) ownerToData; // token id to index array 
    mapping(bytes32 => mapping(uint => PermissionState)) dataToProductPermission; // dataHash => productUid => permissionState
    
    bytes32[] dataHashes; 
    
    event PermissionRequested(uint, bytes32,uint); //lab id, data hash, product uid 
    event PermissionGranted(bytes32); // permission hash

    constructor(string memory _name, string memory _symbol) 
    IdentityToken(_name,_symbol)
    {}

    modifier onlyDataOwner(bytes32 _dHash) {
        uint id = dataToOwner[_dHash];
        require(id == ownerToToken[msg.sender], "REJUVE: Only Data Owner");
        _;
    }

// ---------------------------- STEP 2 : Data Submission ------------------------

    /**
     * @notice Allow user to submit data 
     * @dev Map identity token with Data (struct array index)
    */
    function submitData(string memory _dHash) external ifRegistered {
        bytes32 dhash = keccak256(abi.encodePacked(_dHash)); // for testing
        _submitData(dhash);
    }

//------------------------------ Step 3: Permission Request By Lab ---------------------

    /**
     * @notice Labs can request permission for data usage (Pay rejuve token for data use - add later)
     * @dev Caller should be owner of given Lab ID
     * @param _labId Lab identity token ID
     * @param _nextProductUid AI suggested product ID 
     * @param _dHash Data hash for which permission is granting
    */

    function requestPermission(uint _labId, bytes32 _dHash, uint _nextProductUid) external ifRegistered { 
        require(msg.sender == ownerOf(_labId), "REJUVE: Caller is not owner of Lab ID");
        //check user sent amount after integrating Rejuve utility token
        emit PermissionRequested(_labId,_dHash,_nextProductUid);
    }

//------------------------------ Step 4: Grant Permission By Data Owner ---------------------

    /**
     * @notice Only data owner can grant permission 
    */
    function grantPermission(uint _labId, bytes32 _dHash, uint _nextProductUid) external ifRegistered onlyDataOwner(_dHash){ // only called by owner of data
        _grantPermission(_labId,_dHash,_nextProductUid);
    }

//----------------------------- OTHER SPPORTIVE PUBLIC VIEWS ---------------------

    /**
     * @dev Get index of struct array 
     * Get data based on index
    */
    function getDataByTokenId(uint _tokenId, uint _index) internal view returns(bytes32) {
        uint index = ownerToData[_tokenId][_index] ; // returning index of dataHashes array
        return dataHashes[index];  
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------   

    function _submitData(bytes32 _dHash) private {
        dataHashes.push(_dHash); 
        uint index = dataHashes.length - 1;
        uint tokenId = ownerToToken[msg.sender]; 
        ownerToData[tokenId].push(index); 
        dataToOwner[_dHash] = tokenId; 
    }

    function _grantPermission(uint _labId, bytes32 _dHash, uint _nextProductUid) private {
        bytes32 permissionHash = _generatePermissionHash(_labId,_dHash,_nextProductUid);
        ownerToPermissions[getOwnerId(msg.sender)].push(permissionHash); // save all permissions hashes 
        dataToProductPermission[_dHash][_nextProductUid] = PermissionState.Permitted;

        emit PermissionGranted(permissionHash);
    }

    function _generatePermissionHash(uint _labId, bytes32 _dHash, uint _nextProductUid) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(_labId,_dHash,_nextProductUid));
    }

}
