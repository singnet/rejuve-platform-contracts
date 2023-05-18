const { expect } = require("chai");
let _getSign = require ('./GetSign');

let nonce = 0;
const kycDataHash= "7924fbcf9a7f76ca5412304f2bf47e326b638e9e7c42ecad878ed9c22a8f1428";
const kyc = "0x" + kycDataHash;

async function createIdentity(userAccountAddress, tokenURI, identitycontractAddress, userAccount, sponsor, identityToken) 
{
    ++nonce;
    let sign = await _getSign.getSignForIdentity(userAccountAddress, kyc, tokenURI, nonce, identitycontractAddress, userAccount);   
    await identityToken.connect(sponsor).createIdentity(sign, kyc, userAccountAddress, tokenURI, nonce);
}

module.exports.createIdentity = createIdentity;
