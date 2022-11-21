const { expect } = require("chai");
let _getSign = require ('./modules/GetSign');

describe("Data Management Contract", function () {

    let _identityToken;
    let identityToken;
    let _dataMgt;
    let dataMgt;
    let owner;
    let addr1;
    let addr2;
    let addrs;
    let index=0;
    let signature;
    let dataHash = "0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b"; 
    let nonce = 0;
    let expiration = 2; // 2 days 

    before(async function () {
        // Get the ContractFactory and Signers here.
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await  _identityToken.deploy("Rejuve Identities","RI");

        _dataMgt = await ethers.getContractFactory("DataManagement");
        dataMgt = await _dataMgt.deploy(identityToken.address);
    }); 


    it("Should revert if contract is paused", async function () {

        await dataMgt.pause();
        signature = await _getSign.getSignForData(addr1.address, dataHash, nonce, dataMgt.address,addr1);
        await expect(dataMgt.submitData(addr1.address, signature, dataHash, nonce))
        .to.be.revertedWith("Pausable: paused");
    });

    it("Should revert if data owner not registered", async function () {

        await dataMgt.unpause();
        expect(await identityToken.paused()).to.equal(false);

        signature = await _getSign.getSignForData(addr1.address, dataHash, nonce, dataMgt.address,addr1);
        await expect(dataMgt.submitData(addr1.address, signature, dataHash, nonce))
        .to.be.revertedWith("REJUVE: Not Registered");
    });

    
    it("Should revert if use a signature more than once", async function () {

        // create identity
        let identitySignature = await _getSign.getSignForIdentity(addr1.address, "/tokenURIHere", nonce, identityToken.address, addr1);   
        await identityToken.createIdentity(identitySignature, addr1.address, "/tokenURIHere", nonce);

        // data submission twice with same signature
        await dataMgt.submitData(addr1.address, signature, dataHash, nonce);
        await expect(dataMgt.submitData(addr1.address, signature, dataHash, nonce))
        .to.be.revertedWith("REJUVE: Signature used already");
      
    });
    it("Data hash should be submitted against data owner Id", async function () {
        // create identity for data owner
        ++nonce;
        let identitySignature = await _getSign.getSignForIdentity(addr2.address, "/tokenURIHere", nonce, identityToken.address, addr2);   
        await identityToken.createIdentity(identitySignature, addr2.address, "/tokenURIHere", nonce);
        // submit data on the behalf of data owner 
        ++nonce;
        signature = await _getSign.getSignForData(addr2.address, dataHash, nonce, dataMgt.address,addr2);
        await dataMgt.submitData(addr2.address, signature, dataHash, nonce);
       
        expect(await dataMgt.getDataByTokenId(identityToken.getOwnerIdentity(addr2.address),index++))
        .to.equal(dataHash);

        expect (await dataMgt.getDataOwnerId(dataHash))
       .to.equal(await identityToken.getOwnerIdentity(addr2.address));
    });

    it("should revert if requester is not registered", async function () {
        ++nonce;
        expiration = expiration * 24 * 60 * 60;
        signature = _getSign.getSignForPermission(addr2.address, 3, dataHash, 100, nonce, expiration, dataMgt.address, addr2);
        await expect (dataMgt.getPermission(addr2.address, signature, dataHash, 3, 100, nonce, expiration))  
        .to.be.revertedWith("REJUVE: Not Registered");
    });

    it("should permit lab to use data", async function () {

        // create identity
        +nonce
        let identitySignature = await _getSign.getSignForIdentity(owner.address, "/tokenURIHere", nonce, identityToken.address, owner);   
        await identityToken.createIdentity(identitySignature, owner.address, "/tokenURIHere", nonce);
        // Get data owner signature 
        ++nonce;
        signature = _getSign.getSignForPermission(addr2.address, 3, dataHash, 100, nonce, expiration, dataMgt.address, addr2);
        // Get data access permission
        expect (await dataMgt.getPermissionStatus(dataHash, 100)).to.equal(0);
        await dataMgt.getPermission(addr2.address, signature, dataHash, 3, 100, nonce, expiration);
        expect (await dataMgt.getPermissionStatus(dataHash, 100)).to.equal(1);

        console.log("Deadline for a data hash", await dataMgt.getPermissionDeadline(dataHash, 100));
    });

    it("should revert if requester provided incorrect data owner", async function () {
        ++nonce;
        signature = _getSign.getSignForPermission(addr1.address, 3, dataHash, 100, nonce, expiration, dataMgt.address, addr1);
        await expect(dataMgt.getPermission(addr1.address, signature, dataHash, 3, 100, nonce, expiration))
        .to.be.revertedWith("REJUVE: Not a Data Owner");
    });

    it("should revert if requester provided invalid signature", async function () {
        ++nonce;
        signature = _getSign.getSignForPermission(addr2.address, 3, dataHash, 100, nonce, expiration, dataMgt.address, addr1);
        await expect(dataMgt.getPermission(addr2.address, signature, dataHash, 3, 100, nonce, expiration))
        .to.be.revertedWith("REJUVE: Invalid Signature");
    });

   

});