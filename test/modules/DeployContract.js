const { expect } = require("chai");

let _identityToken;
let identityToken;

let _dataMgt;
let dataMgt;

let _productNFT;
let productNFT;

let arr = [];

async function identityContract() 
{
    _identityToken = await ethers.getContractFactory("IdentityToken");
    identityToken = await  _identityToken.deploy("Rejuve Identities","RI");
    return identityToken;   
}

async function dataMgtContract() 
{
    _dataMgt = await ethers.getContractFactory("DataManagement");
    dataMgt = await _dataMgt.deploy(identityToken.address);
    return dataMgt; 
}

async function productNFTContract() 
{
    _productNFT = await ethers.getContractFactory("ProductNFT"); 
    productNFT = await _productNFT.deploy("Rejuve Products","RP", identityToken.address, dataMgt.address);
    return productNFT;   
}

async function deployAll()
{
    identityToken = await identityContract();
    arr.push(identityToken);

    dataMgt = await dataMgtContract();
    arr.push(dataMgt);

    productNFT = await productNFTContract();
    arr.push(productNFT);

    return arr;
}

module.exports.identityContract = identityContract;
module.exports.dataMgtContract = dataMgtContract;
module.exports.productNFTContract = productNFTContract;
module.exports.deployAll= deployAll;