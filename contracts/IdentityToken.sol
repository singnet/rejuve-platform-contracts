// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/** 
 * @title Identity Management for data contributors
 * @dev Contract module which provides an identity creation mechanism
 * that allows rejuve to create identities on the behalf of user,
 * taking their signature as permission to create identity.
 * Also, users can burn their identities any time
*/
contract IdentityToken is Context, ERC721URIStorage, Ownable, Pausable {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    Counters.Counter private _tokenIdCounter;

    enum UserStatus {
        NotRegistered,
        Registered
    }

    // Mapping from owner to Identity token
    mapping(address => uint256) private ownerToIdentity;

    // Mapping from user to registration status
    mapping(address => UserStatus) private registrations;

    // Mapping from nonce to use status
    mapping(uint256 => bool) private usedNonces;

    /**
     * @dev Emitted when a new Identity is created
     */
    event IdentityCreated(address caller, uint256 tokenId, string tokenURI);

    /**
     * @dev Emitted when identity owner burn his token
     */
    event IdentityDestroyed(address owner, uint256 ownerId);

    /**
     * @dev Throws if called by any account other than token owner.
    */
    modifier onlyIdentityOwner(uint256 tokenId) {
        require(
            tokenId == ownerToIdentity[_msgSender()],
            "REJUVE: Only Identity Owner"
        );
        _;
    }

    modifier ifSignedByUser(
        bytes memory signature,
        address signer,
        string memory tokenURI,
        uint256 nonce
    ) {
        require(
            _verifyMessage(signature, signer, tokenURI, nonce),
            "REJUVE: Invalid Signature"
        );
        _;
    }

    constructor(string memory name, string memory symbol) 
        ERC721(name, symbol) 
    {
        _tokenIdCounter.increment();
    }

    // ---------------------------- STEP 1 : Create Identity token ------------//

    /**
     * @notice Decentralized identitiies for data contributors. 
     * @dev Only one identity token per user
     * @dev Rejuve/sponsor can create identity token for user. User signature is mandatory
     * @param signature user signature
     * @param signer user address
     * @param tokenURI user metadata
     * @param nonce a unique number to prevent replay attacks
     */
    function createIdentity(
        bytes memory signature,
        address signer,
        string memory tokenURI,
        uint256 nonce
    )
        external
        whenNotPaused
        ifSignedByUser(signature, signer, tokenURI, nonce)
    {
        require(
            registrations[signer] == UserStatus.NotRegistered,
            "REJUVE: One Identity Per User"
        );
        _createIdentity(signer, tokenURI);
    }

    /**
     * @notice Burn identity token
     * @dev only identity owner can burn his token
     */
    function burnIdentity(
        uint256 tokenId
    ) 
        external 
        onlyIdentityOwner(tokenId) 
    {
        _burn(tokenId);
        registrations[_msgSender()] = UserStatus.NotRegistered;
        ownerToIdentity[_msgSender()] = 0;

        emit IdentityDestroyed(_msgSender(), tokenId);
    }

    //---------------------------- OWNER FUNCTIONS --------------------------------//

    /**
     * @dev Triggers stopped state.
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

    //----------------------------- EXTERNAL VIEWS --------------------------------//

    /**
     * @return token id (Identity) of the given address.
     */
    function getOwnerIdentity(address owner) external view returns (uint256) {
        return ownerToIdentity[owner];
    }

    /**
     * @return caller registration status.
     */
    function ifRegistered(address userAccount) external view returns (uint8) {
        return uint8(registrations[userAccount]);
    }

    //----------------------------- PRIVATE FUNCTIONS -----------------------------//

    /**
     * @dev Private function to create identity token.
     * @return uint new token id created against caller
    */
    function _createIdentity(
        address userAccount,
        string memory tokenURI
    ) private returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(userAccount, tokenId);
        _setTokenURI(tokenId, tokenURI);
        ownerToIdentity[userAccount] = tokenId;
        registrations[userAccount] = UserStatus.Registered;

        emit IdentityCreated(userAccount, tokenId, tokenURI);
        return tokenId;
    }

    /**
     * @dev Private function to verify user signature
     * Return bool flag true if valid signature
     */
    function _verifyMessage(
        bytes memory signature,
        address signer,
        string memory uri,
        uint256 nonce
    ) private returns (bool flag) {
        require(!usedNonces[nonce], "REJUVE: Signature used already");
        usedNonces[nonce] = true;
        bytes32 messagehash = keccak256(
            abi.encodePacked(signer, uri, nonce, address(this))
        ); // recreate message
        address signerAddress = messagehash.toEthSignedMessageHash().recover(
            signature
        ); // verify signer using ECDSA

        if (signer == signerAddress) {
            flag = true;
        }
    }
}
