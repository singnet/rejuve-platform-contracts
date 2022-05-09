// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IdentityToken.sol";

/** @dev Contract module which provides data submission, 
 *  permission request and granting mechanism.  
 *  It allows a caller to request specific data access.
 *  Data owner can grant permission to access the data.
*/

contract DataManagement {

    enum PermissionState { NotPermitted, Permitted, Rejected } // what's next if data owner rejects data usage request 

    IdentityToken private _identityToken;
    IERC20 private _rejuveToken; 

    mapping(bytes32 => bytes32[]) dataToPermissions; // @dev test mapping if needed (during development)

    // Mapping from data hash to owner identity 
    mapping(bytes32 => uint) dataToOwner; 

    // Mapping from owner identity to permission hashes
    mapping(uint => bytes32[]) ownerToPermissions; 

    // Mapping from owner identity to indexes => [dataHashes]
    mapping(uint => uint[]) ownerToDataIndexes; 

    // Mappin from OwnerIdentity to product UID to data hash
    //mapping(uint => mapping(uint => bytes32[])) ownerToProductToData;

    // Mapping from data hash to nextProductUID to permission state
    mapping(bytes32 => mapping(uint => PermissionState)) dataToProductPermission; 
    
    // Array to store all data hashes 
    bytes32[] dataHashes; 
    
    /**
     * @dev Emitted when a new data hash is submitted  
    */
    event DataSubmitted(address dataOwner, uint dataOwnerId, bytes32 dataHash);

    /**
     * @dev Emitted when permission is requested to access specific data 
     * to be used in a specific product
    */
    event PermissionRequested(uint requesterId, bytes32 dataHash, uint nextProductUID); 

    /**
     * @dev Emitted when permission is granted to access requested data 
     * to be used in a specific product
    */
    event PermissionGranted(uint requesterId, bytes32 dataHash, uint nextProductUID, bytes32 permissionHash); 

    constructor(IdentityToken identityToken_, IERC20 rejuveToken_) 
    {
        _identityToken = identityToken_;
        _rejuveToken = rejuveToken_;
    }

    /**
     * @dev Throws if called by any account other than data owner.
    */
    modifier onlyDataOwner(bytes32 _dHash) {
        uint id = dataToOwner[_dHash];
        require(id == _identityToken.getOwnerIdentity(msg.sender), "REJUVE: Only Data Owner");
        _;
    }

    /**
     * @dev Throws if called by unregistered user.
    */
    modifier ifRegisteredUser {
        require(_identityToken.ifRegistered(msg.sender) == 1, "REJUVE: Not Registered");
        _;
    }

// ---------------------------- STEP 2 : Data Submission ------------------------

    /**
     * @notice Allow only registered users to submit data. 
     * @dev Link owner identity to submitted data hash
    */
    function submitData(bytes32 _dHash) external ifRegisteredUser {
        _submitData(_dHash);
    }

//----------------- Step 3: Permission Request By researcher / Lab ---------------

    /**
     * @notice A caller can ask for permission to access specific data (Pay rejuve token for data use - add later)
     * @dev Caller should be owner of given requester ID
     * @param _requesterId requester identity token ID
     * @param _nextProductUID AI suggested product unique ID 
     * @param _dHash Data hash for which permission is requested
    */

    function requestPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) external ifRegisteredUser { 
        require(msg.sender == _identityToken.ownerOf(_requesterId), "REJUVE: Caller is not owner of Lab ID");
        //check user sent amount after integrating Rejuve utility token

        emit PermissionRequested(_requesterId, _dHash, _nextProductUID);
    }

//--------------------- Step 4: Grant Permission By Data Owner ---------------------

    /**
     * @notice Only data owner can grant permission 
    */
    function grantPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) external ifRegisteredUser onlyDataOwner(_dHash){ // only called by owner of data
        _grantPermission(_requesterId, _dHash, _nextProductUID);
    }

//----------------------------- OTHER SPPORTIVE VIEWS ------------------------------

    /**
     * @dev Get index of [datahashes] 
     * Get data based on index
    */
    function getDataByTokenId(uint _tokenId, uint _index) external view returns(bytes32) {
        uint index = ownerToDataIndexes[_tokenId][_index] ; // returning index of dataHashes array
        return dataHashes[index];  
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------   

    /**
     * @dev Private function to submit data 
     * - Link index of data hash to user identity
     * - Save owner againt data 
    */
    function _submitData(bytes32 _dHash) private {
        dataHashes.push(_dHash); 
        uint index = dataHashes.length - 1;
        uint tokenId = _identityToken.getOwnerIdentity(msg.sender); 
        ownerToDataIndexes[tokenId].push(index); 
        dataToOwner[_dHash] = tokenId;

        emit DataSubmitted(msg.sender, tokenId, _dHash); 
    }

    /**
     * @dev Private function to grant permission
     * - Generate permission hash via ~keccak256
     * - Save all permissions against each owner
     * - Mark data permitted to be used in a specific product 
    */    
    function _grantPermission(uint _requesterId, bytes32 _dHash, uint _nextProductUID) private {
        bytes32 permissionHash = _generatePermissionHash(_requesterId, _dHash, _nextProductUID);
        ownerToPermissions[_identityToken.getOwnerIdentity(msg.sender)].push(permissionHash); // save all permissions hashes 
        dataToProductPermission[_dHash][_nextProductUID] = PermissionState.Permitted;

        emit PermissionGranted(_requesterId, _dHash, _nextProductUID, permissionHash);
    }

    function _generatePermissionHash(uint _requesterId, bytes32 _dHash, uint _nextProductUID) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(_requesterId, _dHash, _nextProductUID));
    }

}
