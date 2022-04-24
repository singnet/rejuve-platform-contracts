// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./Done/DataManagement.sol";

contract ProductNFT is DataManagement {

    mapping(bytes32 => mapping(uint=>uint)) public dataToProductToCredit; 
    mapping(uint => bytes32[]) public productToData; 

    constructor(string memory _name, string memory _symbol) 
    DataManagement(_name,_symbol)
    {}

//------------------------------ Step 5: Creating Product - Transaction by Lab / Rejuve ---------------------

    function createProduct(uint _labId, uint _productUID, bytes32[] memory _dataHashes, uint[] memory creditScores) external ifRegistered {
        require(msg.sender == ownerOf(_labId), "REJUVE: Caller is not owner of Lab ID");
        // add into owner to token id mapping when creating shards
        for(uint i=0; i<dataHashes.length; i++){

            if(dataToProductPermission[_dataHashes[i]][_productUID] == PermissionState.Permitted){ // check if data is permitted for usage
                dataToProductToCredit[dataHashes[i]][_productUID] = creditScores[i];// assigning credits to data hashes 
                productToData[_productUID].push(dataHashes[i]); // mapping data hashes to product uid
            }
           
        } 
        _safeMint(msg.sender, _productUID); // use product id as token Id  
    }


}