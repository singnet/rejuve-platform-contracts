const { expect } = require("chai");

describe("IdentityToken contract", function () {

    let _identityToken;
    let identityToken;
    let owner;
    let addr1;
    let addr2;
    let addrs;
    let tokenId=1;
    const balance = 1;

    beforeEach(async function () {
        // Get the ContractFactory and Signers here.
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
        await identityToken.createIdentityToken();
        await expect(identityToken.createIdentityToken())
        .to.be.revertedWith("REJUVE: One identity per user");
    });

    it("should increase token id by 1 for new user", async function () {
        // user 1
        await identityToken.createIdentityToken();
        expect (await identityToken.balanceOf(owner.address)).to.equal(balance);
        expect (await identityToken.getOwnerId(owner.address)).to.equal(tokenId);

        // user 2
        await identityToken.connect(addr1).createIdentityToken();
        expect (await identityToken.balanceOf(addr1.address)).to.equal(balance);
        expect (await identityToken.getOwnerId(addr1.address)).to.equal(++tokenId);
    });

    it("should burn given token Id", async function () {
        
        await identityToken.createIdentityToken();

        expect (await identityToken.balanceOf(owner.address)).to.equal(1);
        expect (await identityToken.getOwnerId(owner.address)).to.equal(1);

        await identityToken.burnIdentity(identityToken.getOwnerId(owner.address));
        
        expect (await identityToken.balanceOf(owner.address)).to.equal(0);
        expect (await identityToken.getOwnerId(owner.address)).to.equal(0);
    });

});
