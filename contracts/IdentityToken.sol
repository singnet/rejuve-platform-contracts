// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/** @dev Contract module which provides an identity creation mechanism 
 *  that allow users to create and burn their identities.  
*/

contract IdentityToken is ERC721URIStorage, Ownable, Pausable {

    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    Counters.Counter private _tokenIdCounter;

    enum UserStatus { NotRegistered, Registered }

    // Mapping from owner to Identity token
    mapping(address => uint) ownerToIdentity;  

    // Mapping from user to registration status 
    mapping(address => UserStatus) registrations; 

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
        require(_tokenId == ownerToIdentity[msg.sender], "REJUVE: Only Identity Owner");
        _;
    }

    modifier ifSignedByUser(string memory _message, bytes memory _signedMessage, address _userAccount) {
        require(verifyMessage(_message, _signedMessage, _userAccount), "REJUVE: Invalid Signature");
        _;
    }

// ---------------------------- STEP 1 : Create Identity token ------------
  
    /** 
     * @notice Only one identity token per user
     * @dev User or Rejuve can create identity token for user 
     * @dev User signature is mandatory
    */
    function createIdentity(string memory _message, bytes memory _signedMessage, address _userAccount, string memory _tokenURI) 
        external 
        whenNotPaused
        ifSignedByUser(_message, _signedMessage, _userAccount)  
    {
        require(registrations[_userAccount] == UserStatus.NotRegistered, "REJUVE: One Identity Per User");
        _createIdentity(_userAccount, _tokenURI);
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
        registrations[msg.sender] = UserStatus.NotRegistered;
        ownerToIdentity[msg.sender] = 0;

        emit IdentityDestroyed(msg.sender, _tokenId);
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
    function verifyMessage(string memory message, bytes memory signedMessage, address account) 
        private 
        pure 
        returns (bool) 
    {  
        bytes32 messageHash = _generateMsgHash(message);
        return messageHash
            .toEthSignedMessageHash()
            .recover(signedMessage) == account;
    }

    /** 
     * @dev Generate message hash
    */
    function _generateMsgHash(string memory _msg) 
        private 
        pure 
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(_msg));
    }
}
