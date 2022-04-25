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

    mapping(bytes32 => bytes32[]) dataToPermissions; // @dev test mapping if needed (during development)

    // Mapping from data hash to owner identity 
    mapping(bytes32 => uint) dataToOwner; 

    // Mapping from owner identity to permission hashes
    mapping(uint => bytes32[]) ownerToPermissions; 

    // Mapping from owner identity to indexes [dataHashes]
    mapping(uint => uint[]) ownerToData; 

    // Mapping from data hash to nextProductUID to permission state
    mapping(bytes32 => mapping(uint => PermissionState)) dataToProductPermission; 
    
    // Array to store all data hashes 
    bytes32[] dataHashes; 
    
    /**
     * @dev Emitted when a new data hash is submitted  
    */
    event DataSubmitted(address dataOwner, uint dataOwnerId, bytes32 dataHash);

    /**
     * @dev Emitted when permission is requested to access a specific data 
    */
    event PermissionRequested(uint requesterId, bytes32 dataHash, uint nextProductUID); 

    /**
     * @dev Emitted when permission is granted to access requested data 
    */
    event PermissionGranted(uint requesterId, bytes32 dataHash, uint nextProductUID, bytes32 permissionHash); 

    constructor(string memory _name, string memory _symbol) 
    IdentityToken(_name,_symbol)
    {}


    /**
     * @dev Throws if called by any account other than data owner.
    */
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
    function submitData(bytes32 _dHash) external ifRegistered {
        _submitData(_dHash);
    }

//------------------------------ Step 3: Permission Request By Lab ---------------------

    /**
     * @notice Labs can request permission for data usage (Pay rejuve token for data use - add later)
     * @dev Caller should be owner of given Lab ID
     * @param _requesterId requester identity token ID
     * @param _nextProductUID AI suggested product ID 
     * @param _dHash Data hash for which permission is granting
    */

    function requestPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) external ifRegistered { 
        require(msg.sender == ownerOf(_requesterId), "REJUVE: Caller is not owner of Lab ID");
        //check user sent amount after integrating Rejuve utility token

        emit PermissionRequested(_requesterId, _dHash, _nextProductUID);
    }

//------------------------------ Step 4: Grant Permission By Data Owner ---------------------

    /**
     * @notice Only data owner can grant permission 
    */
    function grantPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) external ifRegistered onlyDataOwner(_dHash){ // only called by owner of data
        _grantPermission(_requesterId, _dHash, _nextProductUID);
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

        emit DataSubmitted(msg.sender, tokenId, _dHash); 
    }

    function _grantPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) private {
        bytes32 permissionHash = _generatePermissionHash(_requesterId, _dHash, _nextProductUID);
        ownerToPermissions[getOwnerId(msg.sender)].push(permissionHash); // save all permissions hashes 
        dataToProductPermission[_dHash][_nextProductUID] = PermissionState.Permitted;

        emit PermissionGranted(_requesterId, _dHash, _nextProductUID, permissionHash);
    }

    function _generatePermissionHash(uint _requesterId, bytes32 _dHash, uint _nextProductUID) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(_requesterId, _dHash, _nextProductUID));
    }

}
