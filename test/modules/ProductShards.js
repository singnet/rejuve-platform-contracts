const { expect } = require("chai");

async function createShards(lab, 
    contractAddress, 
    productUID, 
    initialShare, 
    labShare, 
    rejuveShare, 
    labHolder, 
    rejuveHolder, 
    productNFT, 
    productShard
) {
    await productNFT.connect(lab).approve(contractAddress, productUID);    
    await productShard.connect(lab).createInitialShards(
        productUID, 
        initialShare, 
        labShare, 
        rejuveShare, 
        labHolder, 
        rejuveHolder
    );   
}

module.exports.createShards = createShards;
