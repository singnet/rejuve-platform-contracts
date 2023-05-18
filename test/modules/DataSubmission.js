const { expect } = require("chai");
let _getSign = require ('./GetSign');

let nonce = 0;
async function submitDataHash(dataOwnerAddress, dataHash, dataContractAddress, dataOwner, sponsor, dataMgt) 
{
    ++nonce;
    let submissionSign = await _getSign.getSignForData(dataOwnerAddress, dataHash, nonce, dataContractAddress, dataOwner);
    await dataMgt.connect(sponsor).submitData(dataOwnerAddress, submissionSign, dataHash, nonce);
}

async function getAccessPermission(dataOwnerAddress, dataRequestorID, dataHash, productUID, expiration, dataContractAddress, dataOwner, lab, dataMgt){
    ++nonce;
    let permissionSign = _getSign.getSignForPermission(dataOwnerAddress, dataRequestorID, dataHash, productUID, nonce, expiration, dataContractAddress, dataOwner);
    await dataMgt.connect(lab).getPermission(dataOwnerAddress, permissionSign, dataHash, productUID, nonce, expiration);
}

module.exports.submitDataHash = submitDataHash;
module.exports.getAccessPermission = getAccessPermission;
