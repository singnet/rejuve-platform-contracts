const { expect } = require("chai");

let _identityToken;
let identityToken;

let _dataMgt;
let dataMgt;

let _productNFT;
let productNFT;

let _productShard;
let productShard;

let _confirmRFT;
let confirmRFT;

let arr = [];

const shareTarget = 100;
const shareDecimal = 2;
let productUID = 200;

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

async function productShardContract(deployer, rejuveAdmin, curatorFee) 
{
    _productShard = await ethers.getContractFactory("FutureDistribution");
    productShard = await _productShard.connect(deployer).deploy(
        "Rejuve Shards",
        "RS", 
        shareDecimal,
        shareTarget,
        productUID,
        productNFT.address, 
        rejuveAdmin,
        curatorFee
    );

    return productShard;   
}

async function confirmRFTContract() 
{
    _confirmRFT = await ethers.getContractFactory("ConfirmRFT");
    confirmRFT = await  _confirmRFT.deploy();
    return confirmRFT;   
}

async function deployAll(deployer, rejuveAdmin, curatorFee)
{
    identityToken = await identityContract();
    arr.push(identityToken);

    dataMgt = await dataMgtContract();
    arr.push(dataMgt);

    productNFT = await productNFTContract();
    arr.push(productNFT);

    productShard = await productShardContract(deployer, rejuveAdmin, curatorFee);
    arr.push(productShard);

    confirmRFT = await confirmRFTContract();
    arr.push(confirmRFT);

    return arr;
}



module.exports.identityContract = identityContract;
module.exports.dataMgtContract = dataMgtContract;
module.exports.productNFTContract = productNFTContract;
module.exports.productShardContract = productShardContract;
module.exports.confirmRFTContract = confirmRFTContract;
module.exports.deployAll= deployAll;