// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IIdentityToken.sol";

/**
 * @title Data & permission management 
 * @dev Contract module which provides data submission and data access permission features.
 * It allows a caller to request specific data access by taking data owner's signature 
 * as permission.
*/
contract DataManagement is Context, Ownable, Pausable {
    using ECDSA for bytes32;
    IIdentityToken private _identityToken;

    enum PermissionState {
        NotPermitted,
        Permitted
    }

    // Array to store all data hashes
    bytes[] private _dataHashes;

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

    /**
     * @dev Emitted when a new data hash is submitted
    */
    event DataSubmitted(address dataOwner, uint dataOwnerId, bytes dataHash);

    /**
     * @dev Emitted when permission is granted to access requested data
     * to be used in a specific product
    */
    event PermissionGranted(
        uint dataOwnerId,
        uint requesterId,
        bytes dataHash,
        uint nextProductUID,
        bytes32 permissionHash
    );

    constructor(IIdentityToken identityToken_) {
        _identityToken = identityToken_;
    }

    // ---------------------------- STEP 2 : Data Submission ------------------------

    /**
     * @notice Allow rejuve/sponsor to execute transaction
     * @dev Allow only registered data owners
     * @dev check if data owner's signature is valid
     * @dev Link data owner's ID to submitted data hash
    */
    function submitData(
        address signer,
        bytes memory signature,
        bytes memory dHash,
        uint256 nonce
    )
        external
        whenNotPaused
    {
        require(
            _identityToken.ifRegistered(signer) == 1,
            "REJUVE: Not Registered"
        );
        require(
            _verifyDataMessage(signature, signer, dHash, nonce),
            "REJUVE: Invalid Signature"
        );

        _submitData(signer, dHash);
    }

    //--------------------- Step 4: Get Permission By requester to access data ---------------------

    /**
     * @notice Requester is executing transaction
     * @dev Requester should be a registered identity
     * - check if requester provided correct data owner address
     * - check if valid signature is provided
     * @param signer Data owner address
     * @param signature Data owner's signature
     * @param dHash Data hash
     * @param requesterId Requester decentralized identity ID
     * @param nextProductUID General product ID used by requester (Lab)
     * @param nonce A unique number to prevent replay attacks
     * @param expiration A deadline
     */
    function getPermission(
        address signer,
        bytes memory signature,
        bytes memory dHash,
        uint256 requesterId,
        uint256 nextProductUID,
        uint256 nonce,
        uint256 expiration
    ) 
        external 
        whenNotPaused 
    {
        _preValidations(
            _msgSender(),
            signer,
            signature,
            dHash,
            requesterId,
            nextProductUID,
            nonce,
            expiration
        );
        _getPermission(
            signer,
            dHash,
            requesterId,
            nextProductUID,
            expiration
        );
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
    function getDataByTokenId(
        uint tokenId,
        uint index
    ) external view returns (bytes memory) {
        uint dataIndex = ownerToDataIndexes[tokenId][index];
        return _dataHashes[dataIndex];
    }

    /**
     * @notice permission status of a datahash for a product UID
     * @return uint8 0 for not-permitted and 1 for permitted
     */
    function getPermissionStatus(
        bytes memory dHash,
        uint productUID
    ) external view returns (uint8) {
        return uint8(dataToProductPermission[dHash][productUID]);
    }

    // @return data owner identity token ID
    function getDataOwnerId(bytes memory dHash) external view returns (uint) {
        return dataToOwner[dHash];
    }

    /** @notice A Data hash is allowed to be used in a product for a specific time (deadline)
     *  @return uint expiration time in seconds
     */
    function getPermissionDeadline(
        bytes memory dHash,
        uint nextProductUID
    ) external view returns (uint) {
        return dataToProductToExpiry[dHash][nextProductUID];
    }

    //----------------------------- PRIVATE FUNCTIONS ------------------------------------

    /**
     * @dev Private function to submit data
     * - Link index of data hash to user identity
     * - Save owner againt data
     */
    function _submitData(address dataOwner, bytes memory dHash) private {
        _dataHashes.push(dHash);
        uint index = _dataHashes.length - 1;
        uint tokenId = _identityToken.getOwnerIdentity(dataOwner);
        ownerToDataIndexes[tokenId].push(index);
        dataToOwner[dHash] = tokenId;

        emit DataSubmitted(dataOwner, tokenId, dHash);
    }

    /**
     * @dev Private function to verify user signature
     * @dev return true if valid signature
     */
    function _verifyDataMessage(
        bytes memory signature,
        address signer,
        bytes memory dHash,
        uint256 nonce
    ) private returns (bool flag) {
        require(!usedNonces[nonce], "REJUVE: Signature used already");
        usedNonces[nonce] = true;

        bytes32 messagehash = keccak256(
            abi.encodePacked(signer, dHash, nonce, address(this))
        ); // recreate message
        address signerAddress = messagehash.toEthSignedMessageHash().recover(
            signature
        ); // verify signer using ECDSA

        if (signer == signerAddress) {
            flag = true;
        }
    }

    /**
     * @dev Private function to get permission
     * - Generate permission hash via ~keccak256
     * - Save all permissions against each data owner ID
     * - Mark data as "permitted" to be used in a general/next product
     */
    function _getPermission(
        address dataOwner,
        bytes memory dHash,
        uint requesterId,
        uint nextProductUID,
        uint expiration
    ) private {
        bytes32 permissionHash = _generatePermissionHash(
            requesterId,
            dHash,
            nextProductUID
        );
        uint dataOwnerId = _identityToken.getOwnerIdentity(dataOwner);
        ownerToPermissions[dataOwnerId].push(permissionHash); // save all permissions hashes
        dataToProductPermission[dHash][nextProductUID] = PermissionState
            .Permitted;
        dataToProductToExpiry[dHash][nextProductUID] = _calculateDeadline(
            expiration
        );

        emit PermissionGranted(
            dataOwnerId,
            requesterId,
            dHash,
            nextProductUID,
            permissionHash
        );
    }

    /**
     * @dev Pre-validations before data access permission
     * - check if caller is registered identity
     * - check if caller is provided correct data owner
     * - check if valid signature is provided
     */
    function _preValidations(
        address caller,
        address signer,
        bytes memory signature,
        bytes memory dHash,
        uint256 requesterId,
        uint256 nextProductUID,
        uint256 nonce,
        uint256 expiration
    ) private {
        require(
            _identityToken.ifRegistered(caller) == 1,
            "REJUVE: Not Registered"
        );
        uint id = dataToOwner[dHash];
        require(
            id == _identityToken.getOwnerIdentity(signer),
            "REJUVE: Not a Data Owner"
        );
        require(
            _verifyPermissionMessage(
                signature,
                signer,
                requesterId,
                dHash,
                nextProductUID,
                nonce,
                expiration
            ),
            "REJUVE: Invalid Signature"
        );
    }

    /**
     * @dev Private function to verify data owner's signature for permission
     * @dev return true if valid signature
     */
    function _verifyPermissionMessage(
        bytes memory signature,
        address signer,
        uint256 requesterId,
        bytes memory dHash,
        uint256 nextProductUID,
        uint256 nonce,
        uint256 expiration
    ) private returns (bool flag) {
        require(!usedNonces[nonce], "REJUVE: Signature used already");
        usedNonces[nonce] = true;

        bytes32 messagehash = keccak256(
            abi.encodePacked(
                signer,
                requesterId,
                dHash,
                nextProductUID,
                nonce,
                expiration,
                address(this)
            )
        ); // recreate message
        address signerAddress = messagehash.toEthSignedMessageHash().recover(
            signature
        ); // verify signer using ECDSA

        if (signer == signerAddress) {
            flag = true;
        }
    }

    /**
     * @dev calculate permission expiration
     */
    function _calculateDeadline(uint expiration) private view returns (uint) {
        uint deadline = block.timestamp + expiration;
        return deadline;
    }

    function _generatePermissionHash(
        uint requesterId,
        bytes memory dHash,
        uint nextProductUID
    ) private pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(requesterId, dHash, nextProductUID)
        );
    }
}
