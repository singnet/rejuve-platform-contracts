// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IIdentityToken.sol";

/** @dev Contract module which provides data submission and data access permission features.
 * It allows a caller to request specific data access by taking data owner's signature as permission.
*/
contract DataManagement is Context, Ownable, Pausable  {

    using ECDSA for bytes32;
    IIdentityToken private _identityToken;

    enum PermissionState { NotPermitted, Permitted } 

    // Mapping from data hash to owner identity 
    mapping(bytes => uint) private dataToOwner; 

    // Mapping from owner identity to permission hashes
    mapping(uint => bytes32[]) private ownerToPermissions; 

    // Mapping from owner identity to indexes => [dataHashes]
    mapping(uint => uint[]) private ownerToDataIndexes; 

    // Mapping from data hash to nextProductUID to permission state
    mapping(bytes => mapping(uint => PermissionState)) private dataToProductPermission; 

    // Mapping from data hash to nextProductUID to permission deadline
    mapping(bytes => mapping(uint => uint)) private dataToProductToExpiry;

    // Mapping from nonce to use status 
    mapping(uint256 => bool) private usedNonces;

    // Array to store all data hashes 
    bytes[] private dataHashes; 
    
    /**
     * @dev Emitted when a new data hash is submitted  
    */
    event DataSubmitted(address dataOwner, uint dataOwnerId, bytes dataHash);
 
    /**
     * @dev Emitted when permission is granted to access requested data 
     * to be used in a specific product
    */
    event PermissionGranted(uint dataOwnerId, uint requesterId, bytes dataHash, uint nextProductUID, bytes32 permissionHash); 

    constructor(IIdentityToken identityToken_) 
    {
        _identityToken = identityToken_;
    }

    /**
     * @dev Throws if called by unregistered user.
    */
    modifier ifRegisteredUser(address _dataOwner) {
        require(_identityToken.ifRegistered(_dataOwner) == 1, "REJUVE: Not Registered");
        _;
    }

    /**
     * @dev Throws if invalid signature 
    */
    modifier ifSignedByUserForData(address _signer, bytes memory _signature,  bytes memory _dHash, uint256 _nonce) {
        require(_verifyDataMessage(_signature, _signer, _dHash, _nonce), "REJUVE: Invalid Signature");
        _;
    }

// ---------------------------- STEP 2 : Data Submission ------------------------

    /**
     * @notice Allow rejuve/sponsor to execute transaction
     * @dev Allow only registered data owners 
     * @dev check if data owner's signature is valid 
     * @dev Link data owner's ID to submitted data hash
    */
    function submitData(
        address _signer, 
        bytes memory _signature, 
        bytes memory _dHash,
        uint256 _nonce
    ) 
        external 
        whenNotPaused
        ifRegisteredUser(_signer)
        ifSignedByUserForData(_signer, _signature, _dHash, _nonce) 
    
    {
        _submitData(_signer,_dHash);
    }

//--------------------- Step 4: Get Permission By requester to access data ---------------------

    /**
     * @notice Requester is executing transaction 
     * @dev Requester should be a registered identity
     * - check if requester provided correct data owner address
     * - check if valid signature is provided
     * @param _signer Data owner address 
     * @param _signature Data owner's signature
     * @param _dHash Data hash
     * @param _requesterId Requester decentralized identity ID
     * @param _nextProductUID General product ID used by requester (Lab)
     * @param _nonce A unique number to prevent replay attacks
     * @param _expiration A deadline 
    */
    function getPermission(
        address _signer,
        bytes memory _signature, 
        bytes memory _dHash, 
        uint256 _requesterId, 
        uint256 _nextProductUID,
        uint256 _nonce,
        uint256 _expiration
    ) 
        external
        whenNotPaused
    {
        _preValidations(_msgSender(), _signer, _signature, _dHash, _requesterId, _nextProductUID, _nonce, _expiration);
        _getPermission(_signer,_dHash ,_requesterId, _nextProductUID, _expiration);
    }

//---------------------------- OWNER FUNCTIONS --------------------------------
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

//----------------------------- OTHER SPPORTIVE VIEWS ------------------------------

    /**
     * @dev Get index of [datahashes] 
     * Get data based on index
    */
    function getDataByTokenId(uint _tokenId, uint _index) external view returns(bytes memory) {
        uint index = ownerToDataIndexes[_tokenId][_index] ; // returning index of dataHashes array
        return dataHashes[index];  
    }

    /**
     * @notice permission status of a datahash for a product UID
     * @return uint8 0 for not-permitted and 1 for permitted 
     */
    function getPermissionStatus(bytes memory _dHash, uint _productUID) external view returns(uint8) {
        return uint8(dataToProductPermission[_dHash][_productUID]);
    }

    // @return uint data owner identity token ID
    function getDataOwnerId(bytes memory _dHash) external view returns(uint) {
        return dataToOwner[_dHash];
    }

    /** @notice A Data hash is allowed to be used in a product for a specific time (deadline) 
     *  @return uint expiration time in seconds 
     */
    function getPermissionDeadline(bytes memory _dHash, uint _nextProductUID) external view returns(uint) { 
        return dataToProductToExpiry[_dHash][_nextProductUID];
    }

//----------------------------- PRIVATE FUNCTIONS ------------------------------------ 

    /**
     * @dev Private function to submit data 
     * - Link index of data hash to user identity
     * - Save owner againt data 
    */
    function _submitData(
        address _dataOwner, 
        bytes memory _dHash
    ) 
        private 
    {
        dataHashes.push(_dHash); 
        uint index = dataHashes.length - 1;
        uint tokenId = _identityToken.getOwnerIdentity(_dataOwner); 
        ownerToDataIndexes[tokenId].push(index); 
        dataToOwner[_dHash] = tokenId;

        emit DataSubmitted(_dataOwner, tokenId, _dHash); 
    }

    /**
     * @dev Private function to verify user signature 
     * @dev return true if valid signature 
    */
    function _verifyDataMessage(
        bytes memory _signature, 
        address _signer, 
        bytes memory _dHash, 
        uint256 _nonce
    )
        private
        returns (bool _flag)
    {
        require(!usedNonces[_nonce],"REJUVE: Signature used already");
        usedNonces[_nonce] = true;

        bytes32 messagehash = keccak256(abi.encodePacked(_signer, _dHash, _nonce, address(this))); // recreate message
        address signer = messagehash.toEthSignedMessageHash().recover(_signature); // verify signer using ECDSA

        if (_signer == signer) {
            _flag = true;
        } 
        
    }

    /**
     * @dev Private function to get permission
     * - Generate permission hash via ~keccak256
     * - Save all permissions against each data owner ID
     * - Mark data as "permitted" to be used in a general/next product 
    */    
    function _getPermission(
        address _dataOwner,
        bytes memory _dHash,
        uint _requesterId,  
        uint _nextProductUID,
        uint _expiration 
    ) 
        private 
    {
        bytes32 permissionHash = _generatePermissionHash(_requesterId, _dHash, _nextProductUID);
        uint dataOwnerId = _identityToken.getOwnerIdentity(_dataOwner);
        ownerToPermissions[dataOwnerId].push(permissionHash); // save all permissions hashes 
        dataToProductPermission[_dHash][_nextProductUID] = PermissionState.Permitted;
        dataToProductToExpiry[_dHash][_nextProductUID] = _calculateDeadline(_expiration);

        emit PermissionGranted(dataOwnerId, _requesterId, _dHash, _nextProductUID, permissionHash);
    }

    function _generatePermissionHash(
        uint _requesterId, 
        bytes memory _dHash, 
        uint _nextProductUID
    ) 
        private 
        pure 
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_requesterId, _dHash, _nextProductUID));
    }

    /**
     * @dev calculate permission expiration
    */
    function _calculateDeadline(uint _expiration) private view returns(uint) {
        uint deadline = block.timestamp + _expiration ; 
        return deadline;
    }

    /**
     * @dev Pre-validations before data access permission
     * - check if caller is registered identity
     * - check if caller is provided correct data owner
     * - check if valid signature is provided 
    */
    function _preValidations(
        address _caller, 
        address _signer,
        bytes memory _signature, 
        bytes memory _dHash, 
        uint256 _requesterId,  
        uint256 _nextProductUID,
        uint256 _nonce,
        uint256 _expiration
    ) 
        private 
    {
        require(_identityToken.ifRegistered(_caller) == 1, "REJUVE: Not Registered");
        uint id = dataToOwner[_dHash];
        require(id == _identityToken.getOwnerIdentity(_signer), "REJUVE: Not a Data Owner"); 
        require(_verifyPermissionMessage(
            _signature, 
            _signer, 
            _requesterId, 
            _dHash, 
            _nextProductUID, 
            _nonce, 
            _expiration
        ), "REJUVE: Invalid Signature");       
    }

    /**
     * @dev Private function to verify data owner's signature for permission
     * @dev return true if valid signature 
    */
    function _verifyPermissionMessage(
        bytes memory _signature, 
        address _signer, 
        uint256 _requesterId, 
        bytes memory _dHash, 
        uint256 _nextProductUID,
        uint256 _nonce,
        uint256 _expiration
    )
        private
        returns(bool _flag)
    {
        require(!usedNonces[_nonce],"REJUVE: Signature used already");
        usedNonces[_nonce] = true;

        bytes32 messagehash = keccak256(abi.encodePacked(_signer, _requesterId, _dHash, _nextProductUID, _nonce, _expiration, address(this))); // recreate message
        address signer = messagehash.toEthSignedMessageHash().recover(_signature); // verify signer using ECDSA

        if (_signer == signer) {
            _flag = true;
        }
    }

}
