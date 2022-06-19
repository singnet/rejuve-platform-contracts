const { expect } = require("chai");
let _getSign = require ('./GetSign');

describe("Identity Token Contract", function () {

    let _identityToken;
    let identityToken;
    let owner;
    let addr1;
    let addr2;
    let addrs;
    let tokenId=1;
    const balance = 1;
    let userAddress1;
    let userAddress2;
    let nonce = 0;
    let signature;

    before(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await _identityToken.deploy("Rejuve Identities","RUI");
        userAddress1 = addr1.address;
        userAddress2 = addr2.address;
    });  

    it("should assign given name", async function () {
        const name = await identityToken.name();
        expect("Rejuve Identities").to.equal(name);
    });

    it("should assign given symbol", async function () {
        const symbol = await identityToken.symbol();
        expect("RUI").to.equal(symbol);
    });

    it("should create identity", async function () {

        signature = await _getSign.getSignForIdentity(userAddress1, "/tokenURIHere", nonce, identityToken.address, addr1);   
        await identityToken.createIdentity(signature, userAddress1, "/tokenURIHere", nonce);
        expect (await identityToken.balanceOf(userAddress1)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(userAddress1)).to.equal(tokenId);
        expect (await identityToken.ifRegistered(userAddress1)).to.equal(1);
      
    });

    it("Should revert if use a signature more than once", async function () {

        // using same signature
        await expect(identityToken.createIdentity(signature, userAddress1, "/tokenURIHere", nonce)) 
        .to.be.revertedWith("REJUVE: Signature used already");
      
    });

    it("Should revert if signed by user other than identity requester", async function () {

        ++nonce;
        let signature4 = await _getSign.getSignForIdentity(userAddress2, "/tokenURIHere", nonce, identityToken.address, addr1);
        await expect (identityToken.createIdentity(signature4, userAddress2, "/tokenURIHere", nonce)) 
        .to.be.revertedWith("REJUVE: Invalid Signature");
      
    });

    it("should revert if tries to create more than one identity", async function () {

        ++nonce;
        // creating new signature
        let signature2 = await _getSign.getSignForIdentity(userAddress1, "/tokenURI2", nonce, identityToken.address, addr1); 
        await expect(identityToken.createIdentity(signature2, userAddress1, "/tokenURI2", nonce))
        .to.be.revertedWith("REJUVE: One Identity Per User");

    });

    it("should increase token id by 1 for new user", async function () {

        ++nonce;
        let signature3 = await _getSign.getSignForIdentity(userAddress2, "/tokenURIHere", nonce, identityToken.address, addr2);
        await identityToken.createIdentity(signature3, userAddress2, "/tokenURIHere", nonce);
        ++tokenId;
        expect (await identityToken.getOwnerIdentity(userAddress2)).to.equal(tokenId);

    });

    it("should burn given token Id", async function () {

        await identityToken.connect(addr1).burnIdentity(identityToken.getOwnerIdentity(userAddress1));        
        expect (await identityToken.balanceOf(userAddress1)).to.equal(0);
        expect (await identityToken.getOwnerIdentity(userAddress1)).to.equal(0);
        expect (await identityToken.ifRegistered(userAddress1)).to.equal(0);
        await expect (identityToken.tokenURI( identityToken.getOwnerIdentity(userAddress1)))
        .to.be.revertedWith("ERC721URIStorage: URI query for nonexistent token");

    });

    it("should revert if burn is called by user other than owner", async function () {

        await expect(identityToken.burnIdentity(identityToken.getOwnerIdentity(userAddress2)))
        .to.be.revertedWith("REJUVE: Only Identity Owner");
  
    });

    it("should revert if contract is paused", async function () {

        await identityToken.pause();
        expect(await identityToken.paused()).to.equal(true);
        ++nonce;
        let signature3 = await _getSign.getSignForIdentity(userAddress1, "/tokenURIHere", nonce, identityToken.address, addr1);   
        await expect(identityToken.createIdentity(signature3, userAddress1, "/tokenURIHere", nonce))
        .to.be.revertedWith("Pausable: paused");

        await identityToken.unpause();
        expect(await identityToken.paused()).to.equal(false);

    });
    

});
