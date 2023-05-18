const { expect } = require("chai");
let identity = require("./modules/CreateIdentity");
let data = require("./modules/DataSubmission");
let deploy = require("./modules/DeployContract");

describe("Product NFT New contract", function () {
    let identityToken;
    let dataMgt;
    let productNFT;
    let _identityToken;
    let _dataMgt;
    let _productNFT;
    let rejuveAdmin;
    let dataOwner1;
    let dataOwner2;
    let sponsor;
    let lab;
    let addrs;
    let productUID = 200;
    let creatorID;
    let expiration = 2;
    expiration = expiration * 24 * 60 * 60;

    let dataHash1 =
    "0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b";
    let dataHash2 =
    "0x7012f98e24c6b2f609d365c959c99a9bc691d6939cc7162e679fb1226697a56b";
    let newDataHash =
    "0x1988284e7250800b37f11b3fbe7b25ad52b72cb5caff67934f69015a4263ffb5";

    const kycDataHash= "7924fbcf9a7f76ca5412304f2bf47e326b638e9e7c42ecad878ed9c22a8f1428";
    const kyc = "0x" + kycDataHash;

    before (async function () {
        [rejuveAdmin, dataOwner1, dataOwner2, sponsor, lab, ...addrs] = await ethers.getSigners();

    //-------------------- Deploy contracts ----------------------/

        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await  _identityToken.deploy("Rejuve Identities","RI");

        _dataMgt = await ethers.getContractFactory("DataManagement");
        dataMgt = await _dataMgt.deploy(identityToken.address);

        _productNFT = await ethers.getContractFactory("ProductNFT"); 
        productNFT = await _productNFT.deploy("Rejuve Products","RP", identityToken.address, dataMgt.address);

    //------------------ Create Identities -------------------------/

        // Create identity by rejuve sponsor for data owner 1
        await identity.createIdentity(
            dataOwner1.address,
            "/tokenURIHere",
            identityToken.address,
            dataOwner1,
            sponsor,
            identityToken
        );
    
        // Create identity by rejuve sponsor for data owner 2
        await identity.createIdentity(
            dataOwner2.address,
            "/tokenURIHere",
            identityToken.address,
            dataOwner2,
            sponsor,
            identityToken
        );

        // Create identity by lab for itself
        await identity.createIdentity(
            lab.address,
            "/tokenURIHere",
            identityToken.address,
            lab,
            lab,
            identityToken
        );

    //------------------- Data Submission -------------------------/

        // submit data on the behalf of data owner 1
        await data.submitDataHash(
            dataOwner1.address,
            dataHash1,
            dataMgt.address,
            dataOwner1,
            sponsor,
            dataMgt
        );

        // submit data 1 on the behalf of data owner 2
        await data.submitDataHash(
            dataOwner2.address,
            dataHash2,
            dataMgt.address,
            dataOwner2,
            sponsor,
            dataMgt
        );

        // submit data 2 on the behalf of data owner 2
        await data.submitDataHash(
            dataOwner2.address,
            newDataHash,
            dataMgt.address,
            dataOwner2,
            sponsor,
            dataMgt
        );
    })    

    //------------------------ Initial setting tests --------------------
 
    it("Should set product collection name", async function () {
        expect (await productNFT.name()).to.equal("Rejuve Products");
    })

    it("Should set product collection symbol", async function () {
        expect (await productNFT.symbol()).to.equal("RP");
    })

    //---------------------- Pause & unpause -----------------------------

    it("Should revert if contract paused by user other than owner", async function () {
        await expect(productNFT.connect(sponsor).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");
    })

    it("Should revert if contract is paused", async function () {

        await productNFT.pause();
        await expect(productNFT.connect(lab).createProduct(
            3,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("Pausable: paused");

        expect (await productNFT.paused()).to.equal(true);
    });

    it("Should revert if contract unpaused by user other than owner", async function () {
        await expect(productNFT.connect(sponsor).unpause())
        .to.be.revertedWith("Ownable: caller is not the owner");
    })

    it("Should unpause contract", async function () {
        await productNFT.unpause();
        expect (await productNFT.paused()).to.equal(false);
    })

    //--------------------- Registration -----------------------------------

    it("Should revert if product creator is not registered", async function () {
        await expect(productNFT.connect(sponsor).createProduct(
            3,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Not Registered");
    })


    it("Should revert if product creator is using someone else ID", async function () {
    
        await expect(productNFT.connect(lab).createProduct(
            1,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Caller is not owner of lab ID");
    })  
    
    it("Should revert if data & credits array length is not equal", async function () {

        creatorID = await identityToken.getOwnerIdentity(lab.address);
        await expect(productNFT.connect(lab).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20,30]
        )).to.be.revertedWith("REJUVE: Not equal length");
    })    

    //---------------------- Data permission -------------------------------

    it("Should revert if all given data is not permitted to use", async function () {

        creatorID = await identityToken.getOwnerIdentity(lab.address);
        await expect(productNFT.connect(lab).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted");
    });    

    it("Should revert if one of all given data hashes is not permitted to use", async function () {
        // Get lab token ID (data requestor ID)
        let labID = await identityToken.getOwnerIdentity(lab.address);

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
        );

        //Product Creation by lab
        await expect(productNFT.connect(lab).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted"); 
    })

//---------------------------------- Create product ------------------------------------------

    it("Should revert if caller is not registered", async function () {
        //Get permission from data owner 2
        await data.getAccessPermission(
            dataOwner2.address,
            creatorID,
            dataHash2,
            productUID,
            expiration,
            dataMgt.address,
            dataOwner2,
            lab,
            dataMgt
        );

        //Product Creation by lab
        await expect(productNFT.connect(sponsor).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Not Registered"); 
    })

    it("Should revert if caller is not an ID owner - create", async function () {
        //Product Creation by lab
        await expect( productNFT.connect(lab).createProduct(
            1,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Caller is not owner of lab ID"); 
    })


    it("Should revert if length is not equal - create", async function () {
        //Product Creation by lab
        await expect( productNFT.connect(lab).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20,30]
        )).to.be.revertedWith("REJUVE: Not equal length"); 
    })





    it("Should create product", async function () {
        //Product Creation by lab
        await productNFT.connect(lab).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        ); 

        expect (await productNFT.ownerOf(productUID)).to.equal(lab.address);
        expect (await productNFT.tokenURI(productUID)).to.equal("/ProductURI");    
        expect (await productNFT.balanceOf(lab.address)).to.equal(1);
        expect (await productNFT.name()).to.equal("Rejuve Products");
        expect (await productNFT.symbol()).to.equal("RP");
        expect (await productNFT.getInitialDataLength(productUID)).to.equal(2);  
        let arr = await productNFT.getProductToData(productUID);
        expect (arr.length).to.equal(2);       
        expect (arr[0]).to.equal(dataHash1);
        expect (arr[1]).to.equal(dataHash2);
        
        expect (await productNFT.getDataCredit(dataHash1, productUID)).to.equal(10);
        expect (await productNFT.getDataCredit(dataHash2, productUID)).to.equal(20);
        expect (await productNFT.getDataOwnerAddress(dataHash1)).to.equal(dataOwner1.address);    
        expect (await productNFT.getDataOwnerAddress(dataHash2)).to.equal(dataOwner2.address);         
    })

//-------------------------------- Link New data to existing product ------------------------------   


    it("Should revert if called by user other than product owner", async function () {
        await expect(productNFT.linkNewData(productUID, [newDataHash], [30]))
        .to.be.revertedWith("REJUVE: Only Product Creator");  
    })

    it("Should revert if trying to link data when contract is paused", async function () {
        await productNFT.pause();
        await expect(productNFT.connect(lab).linkNewData(productUID, [newDataHash], [30]))
        .to.be.revertedWith("Pausable: paused");  
    })

    it("Should revert if data length is not equal", async function () {
        await productNFT.unpause();
        await expect(productNFT.connect(lab).linkNewData(productUID, [newDataHash], [30, 20]))
        .to.be.revertedWith("REJUVE: Not equal length");     
    });

    it("Should revert if data is not permitted", async function () {
        await expect(productNFT.connect(lab).linkNewData(productUID, [newDataHash], [20]))
        .to.be.revertedWith("REJUVE: Data Not Permitted");     
    });


    it("Should link new data to existing product", async function () {

        // Get permission for new data hash from data owner 2
        await data.getAccessPermission(
            dataOwner2.address,
            creatorID,
            newDataHash,
            productUID,
            expiration,
            dataMgt.address,
            dataOwner2,
            lab,
            dataMgt
        );

        // Link new data by product owner
        await productNFT.connect(lab).linkNewData(productUID, [newDataHash], [20]);
        let dataArray2 = await productNFT.getProductToData(productUID);

        let dataArray = [dataHash1, dataHash2, newDataHash];
        expect (dataArray2.length).to.equal(3);

        for (let i=0; i < dataArray2.length; i++){
            expect (dataArray2[i]).to.equal(dataArray[i]);
        }       
    });



    
})    




