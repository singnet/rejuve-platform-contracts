// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/** @dev Contract module which provides an identity creation mechanism 
 *  that allow users to create and burn their identities. 
 *  Only Identity owner can burn their identity.  
*/

contract IdentityToken is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum UserStatus { NotRegistered, Registered }
    mapping(address => uint) public ownerToToken;  
    mapping(address => UserStatus) public registrations; 

    event IdentityCreated(address,uint);
    event IdentityDestroyed(address,uint);

    constructor(string memory _name, string memory _symbol)
        ERC721(_name,_symbol)
    {
        _tokenIdCounter.increment();
    }

    modifier onlyIdentityOwner(uint256 _tokenId) {
        require(_tokenId == ownerToToken[msg.sender], "REJUVE: Only Identity Owner");
        _;
    }

    modifier ifRegistered() {
        require(registrations[msg.sender] == UserStatus.Registered, "REJUVE: Not Registered");
        _;
    }

// ---------------------------- STEP 1 : Create Identity token ------------
  
    /** 
     * @notice Only one identity token per user
     * @dev Create token and assign token id to user 
    */
    function createIdentityToken() external {
        require(registrations[msg.sender] == UserStatus.NotRegistered, "REJUVE: One identity per user");
        _createIdentityToken();
    }
      
    /** 
     * @notice Burn identity token 
     * @dev only identity owner can burn his token
    */
    function burnIdentity(uint256 _tokenId) external onlyIdentityOwner(_tokenId) {
        _burn(_tokenId);
        registrations[msg.sender] = UserStatus.NotRegistered;
        ownerToToken[msg.sender] = 0;

        emit IdentityDestroyed(msg.sender, _tokenId);
    }

//----------------------------- ALL VIEWS --------------------------------

    function getOwnerId(address _owner) public view returns (uint) { 
        return ownerToToken[_owner]; 
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------    

    function _createIdentityToken() private returns(uint256) { 
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);       
        ownerToToken[msg.sender] = tokenId;
        registrations[msg.sender] = UserStatus.Registered;

        emit IdentityCreated(msg.sender, tokenId);
        return tokenId;
    }


}
