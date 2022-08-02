// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/** @dev Contract module which provides an identity creation mechanism 
 *  that allows rejuve to create identities on the behalf of user,
 *  taking their signature as permission to create identity. 
 *  Also, users can burn their identities any time
*/

contract IdentityToken is Context, ERC721URIStorage, Ownable, Pausable {

    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    Counters.Counter private _tokenIdCounter;

    enum UserStatus { NotRegistered, Registered }

    // Mapping from owner to Identity token
    mapping(address => uint) private ownerToIdentity;  

    // Mapping from user to registration status 
    mapping(address => UserStatus) private registrations; 

   // Mapping from nonce to use status 
    mapping(uint256 => bool) private usedNonces;

    /**
     * @dev Emitted when a new Identity is created 
    */
    event IdentityCreated(address caller, uint tokenId);

    /**
     * @dev Emitted when identity owner burn his token
    */
    event IdentityDestroyed(address owner, uint ownerId);

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        _tokenIdCounter.increment();
    }

    /**
     * @dev Throws if called by any account other than token owner.
    */
    modifier onlyIdentityOwner(uint _tokenId) {
        require(_tokenId == ownerToIdentity[_msgSender()], "REJUVE: Only Identity Owner");
        _;
    }

    modifier ifSignedByUser(bytes memory _signature, address _signer, string memory _tokenURI, uint256 _nonce) {
        require(verifyMessage(_signature, _signer, _tokenURI, _nonce), "REJUVE: Invalid Signature");
        _;
    }

// ---------------------------- STEP 1 : Create Identity token ------------
  
    /** 
     * @notice Only one identity token per user
     * @dev Rejuve/sponsor can create identity token for user. User signature is mandatory
     * @param _signature user signature
     * @param _signer user address 
     * @param _tokenURI user metadata
     * @param _nonce a unique number to prevent replay attacks
    */
    function createIdentity(bytes memory _signature, address _signer, string memory _tokenURI, uint256 _nonce) 
        external 
        whenNotPaused 
        ifSignedByUser(_signature, _signer, _tokenURI, _nonce)  
    {
        require(registrations[_signer] == UserStatus.NotRegistered, "REJUVE: One Identity Per User");
        _createIdentity(_signer, _tokenURI);
    }
      
    /**  
     * @notice Burn identity token 
     * @dev only identity owner can burn his token
    */
    function burnIdentity(uint _tokenId) 
        external 
        onlyIdentityOwner(_tokenId) 
    {
        _burn(_tokenId);
        registrations[_msgSender()] = UserStatus.NotRegistered;
        ownerToIdentity[_msgSender()] = 0;

        emit IdentityDestroyed(_msgSender(), _tokenId);
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

//----------------------------- EXTERNAL VIEWS --------------------------------

    /**
     * @return token id (Identity) of the given address.
    */
    function getOwnerIdentity(address _owner) 
        external 
        view 
        returns(uint) 
    { 
        return ownerToIdentity[_owner]; 
    }

    /**
     * @return caller registration status.
    */
    function ifRegistered(address _userAccount) 
        external 
        view 
        returns(uint8) 
    {
        return uint8(registrations[_userAccount]);
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------    

    /**
     * @dev Private function to create identity token.
     * @return uint new token id created against caller 
    */
    function _createIdentity(address _userAccount, string memory _tokenURI) 
        private 
        returns(uint) 
    { 
        uint tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_userAccount, tokenId); 
        _setTokenURI(tokenId, _tokenURI);      
        ownerToIdentity[_userAccount] = tokenId;
        registrations[_userAccount] = UserStatus.Registered;

        emit IdentityCreated(_userAccount, tokenId);
        return tokenId;
    }

    /**
     * @dev Private function to verify user signature 
     * @return bool true if valid signature 
    */
    function verifyMessage(bytes memory _signature, address _signer, string memory _uri, uint256 _nonce)
        private
        returns (bool)
    {
        require(!usedNonces[_nonce],"REJUVE: Signature used already");
        usedNonces[_nonce] = true;
        bytes32 messagehash = keccak256(abi.encodePacked(_signer, _uri, _nonce, address(this))); // recreate message
        address signer = messagehash.toEthSignedMessageHash().recover(_signature); // verify signer using ECDSA

        if (_signer == signer) {
            return true;
        } 
        
        else {
            return false;
        }
    }
}
