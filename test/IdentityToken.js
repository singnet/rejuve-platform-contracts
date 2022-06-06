const { expect } = require("chai");

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

    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await _identityToken.deploy("Rejuve Users","RUI");
        userAddress1 = addr1.address;
        userAddress2 = addr2.address;

    });  

    it("should assign given name", async function () {
        const name = await identityToken.name();
        expect("Rejuve Users").to.equal(name);
    });

    it("should assign given symbol", async function () {
        const symbol = await identityToken.symbol();
        expect("RUI").to.equal(symbol);
    });

    it("should revert if tries to create more than one identity", async function () {
        await identityToken.createIdentity(userAddress1,"/tokenURIHere");
        await expect(identityToken.createIdentity(userAddress1,"/tokenURIHere"))
        .to.be.revertedWith("REJUVE: One Identity Per User");
    });

    it("should increase token id by 1 for new user", async function () {
        // user 1
        await identityToken.createIdentity(userAddress1,"/tokenURIHere");
        expect (await identityToken.balanceOf(userAddress1)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(userAddress1)).to.equal(tokenId);

        // user 2
        await identityToken.createIdentity(userAddress2,"/tokenURIHere");
        expect (await identityToken.balanceOf(userAddress2)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(userAddress2)).to.equal(++tokenId);
    });

    it("should burn given token Id", async function () {
        
        await identityToken.createIdentity(userAddress1,"/tokenURIHere");

        expect (await identityToken.balanceOf(userAddress1)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(userAddress1)).to.equal(1);
        expect (await identityToken.ifRegistered(userAddress1)).to.equal(1);
        expect (await identityToken.tokenURI(await identityToken.getOwnerIdentity(userAddress1))).to.equal("/tokenURIHere");
      
        await identityToken.connect(addr1).burnIdentity(identityToken.getOwnerIdentity(userAddress1));
        
        expect (await identityToken.balanceOf(userAddress1)).to.equal(0);
        expect (await identityToken.getOwnerIdentity(userAddress1)).to.equal(0);
        expect (await identityToken.ifRegistered(userAddress1)).to.equal(0);
        await expect (identityToken.tokenURI( identityToken.getOwnerIdentity(userAddress1)))
        .to.be.revertedWith("ERC721URIStorage: URI query for nonexistent token");

    });

});
