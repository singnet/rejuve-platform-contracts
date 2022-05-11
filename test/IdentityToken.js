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

    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await _identityToken.deploy("Rejuve Users","RUI");

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
        await identityToken.createIdentity("/tokenURIHere");
        await expect(identityToken.createIdentity("/tokenURIHere"))
        .to.be.revertedWith("REJUVE: One Identity Per User");
    });

    it("should increase token id by 1 for new user", async function () {
        // user 1
        await identityToken.createIdentity("/tokenURIHere");
        expect (await identityToken.balanceOf(owner.address)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(owner.address)).to.equal(tokenId);

        // user 2
        await identityToken.connect(addr1).createIdentity("/tokenURIHere");
        expect (await identityToken.balanceOf(addr1.address)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(addr1.address)).to.equal(++tokenId);
    });

    it("should burn given token Id", async function () {
        
        await identityToken.createIdentity("/tokenURIHere");

        expect (await identityToken.balanceOf(owner.address)).to.equal(balance);
        expect (await identityToken.getOwnerIdentity(owner.address)).to.equal(1);
        expect (await identityToken.ifRegistered(owner.address)).to.equal(1);

        await identityToken.burnIdentity(identityToken.getOwnerIdentity(owner.address));
        
        expect (await identityToken.balanceOf(owner.address)).to.equal(0);
        expect (await identityToken.getOwnerIdentity(owner.address)).to.equal(0);
        expect (await identityToken.ifRegistered(owner.address)).to.equal(0);
    });

});
