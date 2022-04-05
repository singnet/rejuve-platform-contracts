// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract IdentityToken is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    mapping(address => uint) ownerToToken;  
    mapping(uint => uint[]) tokenToData; // token id to index array 
    mapping (address => uint) ownerIdentityCount;

    struct Data{
        string dHash;
        string pHash;
    }

    Data[] data;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name,_symbol)
    {}


//----------------------------- ALL VIEWS ---------------------------------

    /**
     * @dev Get index of struct array 
     * Get data based on index
    */

    function getDataByTokenId(uint _tokenId, uint _index) public view returns(string memory,string memory) {
        
        uint index = tokenToData[_tokenId][_index] ; // returning index of Struct
        return (data[index].dHash , data[index].pHash); // returning struct data as per index
        
    }
  
// ---------------------------- STEP 1 : Create Identity token ------------
  
    /** 
     * @notice Only one identity token per user
     * @dev Create token and assign token id to user 
    */
    
    function createIdentityToken() public {
        require(ownerIdentityCount[msg.sender] == 0, "REJUVE: One identity per user"); 
        _createIdentityToken();

    }


// ---------------------------- STEP 2 : Adding data ------------------------

    /**
     * @notice Allow user to add data 
     * @dev Map identity token with Data (struct array index)
    */

    function addData(string memory _dHash, string memory _pHash) public {
        _addData(_dHash, _pHash);
    }

//----------------------------- PRIVATE FUNCTIONS -----------------------------    


    function _createIdentityToken() private { 
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);       

        ownerToToken[msg.sender] = tokenId;
        ownerIdentityCount[msg.sender]++;
    }


    function _addData(string memory _dHash, string memory _pHash) private {
  
        data.push(Data(_dHash,_pHash));
        uint index = data.length - 1;
        uint tokenId = ownerToToken[msg.sender]; // returning token Id

        tokenToData[tokenId].push(index); 
    }


}
