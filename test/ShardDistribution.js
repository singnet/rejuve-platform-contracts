const { expect } = require("chai");
let _getSign = require ('./modules/GetSign');
let deploy = require('./modules/DeployContract');
let identity = require('./modules/CreateIdentity');
let data = require ('./modules/DataSubmission');
let shards = require('./modules/ProductShards');


describe("Shard Distribution Contract", function () {
    
    let identityToken;
    let dataMgt;
    let productNFT;
    let productShard;
    let confirmRFT;

    let dataOwner1;
    let dataOwner2;
    let rejuveSponsor;
    let addr3;
    let lab; 
    let labID;
    let rejuveAdmin; 
    let clinic;
    let dataOwner3; // new data owner
    let addrs;

    let dataHash1="0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b";
    let dataHash2 = "0x7012f98e24c6b2f609d365c959c99a9bc691d6939cc7162e679fb1226697a56b";
    let newDataHash = "0x1988284e7250800b37f11b3fbe7b25ad52b72cb5caff67934f69015a4263ffb5";

    let productUID = 200;
    let expiration = 2;
    expiration = expiration * 24 * 60 * 60;
    const shareTarget = 100;
    const shareDecimal = 2;
    const calculatedTarget = shareTarget * 10**(shareDecimal);
   
    before (async function () {

        [dataOwner1, dataOwner2, rejuveSponsor, addr3, lab, rejuveAdmin, clinic, dataOwner3, ...addrs] = await ethers.getSigners();
        
        //-------------------- Deploy contracts ----------------------/

        let contractInstance = await deploy.deployAll(lab, rejuveAdmin.address, 100);
        identityToken = contractInstance[0];
        dataMgt = contractInstance[1];
        productNFT = contractInstance[2];
        productShard = contractInstance[3];
        confirmRFT = contractInstance[4];

        //------------------ Create Identities -------------------------/

        // Create identity by rejuve sponsor for data owner 1
        await identity.createIdentity(dataOwner1.address, "/tokenURIHere", identityToken.address, dataOwner1, rejuveSponsor, identityToken) 

        // Create identity by rejuve sponsor for data owner 2
        await identity.createIdentity(dataOwner2.address, "/tokenURIHere", identityToken.address, dataOwner2, rejuveSponsor, identityToken) 

        // Create identity by rejuve sponsor for data owner 3
        await identity.createIdentity(dataOwner3.address, "/tokenURIHere", identityToken.address, dataOwner3, rejuveSponsor, identityToken) 

        // Create identity by lab for itself
        await identity.createIdentity(lab.address, "/tokenURIHere", identityToken.address, lab, lab, identityToken); 

        //------------------- Data Submission -------------------------/

        // submit data on the behalf of data owner 1
        await data.submitDataHash(dataOwner1.address, dataHash1, dataMgt.address, dataOwner1, rejuveSponsor, dataMgt);

        // submit data on the behalf of data owner 2
        await data.submitDataHash(dataOwner2.address, dataHash2, dataMgt.address, dataOwner2, rejuveSponsor, dataMgt);
        
        // submit data on the behalf of data owner 3 
        await data.submitDataHash(dataOwner3.address, newDataHash, dataMgt.address, dataOwner3, rejuveSponsor, dataMgt);

        //----------------- Get Permission -------------------------------/
        
        // Get lab token ID (data requestor ID)
        labID = await identityToken.getOwnerIdentity(lab.address);

        // Get permission from data owner 1
        await data.getAccessPermission(
            dataOwner1.address, 
            labID, 
            dataHash1, 
            productUID, 
            expiration, 
            dataMgt.address, 
            dataOwner1, 
            lab,
            dataMgt
        )

        // Get permission from data owner 2
        await data.getAccessPermission(
            dataOwner2.address, 
            labID, 
            dataHash2, 
            productUID, 
            expiration, 
            dataMgt.address, 
            dataOwner2, 
            lab,
            dataMgt
        )

    }); 

    it("Should create product ", async function () {
        
        // Product Creation by lab (lab)
        await productNFT.connect(lab).createProduct(
            labID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        ); 

        expect (await productNFT.ownerOf(productUID)).to.equal(lab.address);
        expect (await productNFT.tokenURI(productUID)).to.equal("/ProductURI");      
    });

    it("Should be reverted if contract is paused", async function () {
        
        await productShard.connect(rejuveAdmin).pause();
        await expect(shards.createShards(
            lab, 
            productShard.address, 
            productUID,
            25, 
            10, 
            40, 
            lab.address, 
            rejuveAdmin.address, 
            productNFT, 
            productShard
        )).to.be.revertedWith("Pausable: paused");
    })


    it("Should revert if caller is other than product creator", async function () {
        
        await expect(shards.createShards(
            addr3, 
            productShard.address, 
            productUID,
            25, 
            10, 
            40, 
            lab.address, 
            rejuveAdmin.address, 
            productNFT, 
            productShard
        )).to.be.revertedWith("ERC721: approve caller is not owner nor approved for all"); 
    })

//-------------------------------------- Phase 1: Initial Contributors----------------------------------      

    it("Should create product initial shards ", async function () {

        await productShard.connect(rejuveAdmin).unpause();
        await shards.createShards(
            lab, 
            productShard.address, 
            productUID,
            25, 
            10, 
            40, 
            lab.address, 
            rejuveAdmin.address, 
            productNFT, 
            productShard
        ); 

        expect (await productShard.totalSupply()).to.equal(7475);
        expect (await productShard.parentToken()).to.equal(productNFT.address);
        expect (await productShard.parentTokenId()).to.equal(productUID);
        expect (await confirmRFT.confirmRFT(productShard.address)).to.equal(true);
        expect (await productShard.decimals()).to.equal(shareDecimal);
        expect (await productShard.getTargetSupply()).to.equal(calculatedTarget);
    })


//-------------------------------------- Phase 2: Future Contributors-------------------------------------  

    it("Should create product future shards ", async function () {

        // Get permission from data owner 3
        await data.getAccessPermission(
            dataOwner3.address, 
            labID, 
            newDataHash, 
            productUID, 
            expiration, 
            dataMgt.address, 
            dataOwner3, 
            lab,
            dataMgt
        )
        
        // Link new data
        await productNFT.connect(lab).linkNewData(productUID, [newDataHash], [30]);

        // Create future shards 
        await productShard.connect(lab).createFutureShards(productUID, 25, 50, clinic.address);

        expect (await productShard.balanceOf(dataOwner3.address)).to.equal(925);
        expect (await productShard.balanceOf(clinic.address)).to.equal(1550); 

    })

    it("Should create remaining shards", async function () {
        await productShard.createRemainingShards(productUID, rejuveAdmin.address);
        expect (await productShard.balanceOf(rejuveAdmin.address)).to.equal(4050);
    })

})