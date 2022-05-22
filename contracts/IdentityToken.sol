// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/** @dev Contract module which provides an identity creation mechanism 
 *  that allow users to create and burn (optional feature) their identities.  
*/

contract IdentityToken is ERC721URIStorage {

    using Counters for Counters.Counter;
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

// ---------------------------- STEP 1 : Create Identity token ------------
  
    /** 
     * @notice Only one identity token per user
     * @dev Create token and assign token id to user 
    */
    function createIdentity(string memory _tokenURI) external {
        require(registrations[msg.sender] == UserStatus.NotRegistered, "REJUVE: One Identity Per User");
        _createIdentity(_tokenURI);
    }
      
    /** 
     * @notice Burn identity token 
     * @dev only identity owner can burn his token
    */
    function burnIdentity(uint _tokenId) external onlyIdentityOwner(_tokenId) {
        _burn(_tokenId);
        registrations[msg.sender] = UserStatus.NotRegistered;
        ownerToIdentity[msg.sender] = 0;

        emit IdentityDestroyed(msg.sender, _tokenId);
    }

//----------------------------- EXTERNAL VIEWS --------------------------------

    /**
     * @dev Returns token id (Identity) of the given address.
    */
    function getOwnerIdentity(address _owner) external view returns(uint) { 
        return ownerToIdentity[_owner]; 
    }

    /**
     * @dev Returns caller registration status.
    */
    function ifRegistered(address _userAddress) external view returns(uint8) {
        return uint8(registrations[_userAddress]);
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------    

    /**
     * @dev Private function to create identity token.
     * @return uint new token id created against caller 
    */
    function _createIdentity(string memory _tokenURI) private returns(uint) { 
        uint tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId); 
        _setTokenURI(tokenId, _tokenURI);      
        ownerToIdentity[msg.sender] = tokenId;
        registrations[msg.sender] = UserStatus.Registered;

        emit IdentityCreated(msg.sender, tokenId);
        return tokenId;
    }

}
