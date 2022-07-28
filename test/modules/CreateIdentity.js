const { expect } = require("chai");
let _getSign = require ('./GetSign');

let nonce = 0;

async function createIdentity(userAccountAddress, tokenURI, identitycontractAddress, userAccount, sponsor, identityToken) 
{
    ++nonce;
    let sign = await _getSign.getSignForIdentity(userAccountAddress, tokenURI, nonce, identitycontractAddress, userAccount);   
    await identityToken.connect(sponsor).createIdentity(sign, userAccountAddress, tokenURI, nonce);
}

module.exports.createIdentity = createIdentity;
