const { expect } = require("chai");
let _getSign = require ('./modules/GetSign');


describe("Product NFT Contract", function () {

    let _identityToken;
    let identityToken;
    let _dataMgt;
    let dataMgt;
    let _productNFT;
    let productNFT;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addr4; // lab
    let addrs;
    let productUID = 100;
    let dataHash1="0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b";
    let dataHash2 = "0x7012f98e24c6b2f609d365c959c99a9bc691d6939cc7162e679fb1226697a56b";
    let newDataHash = "0x1988284e7250800b37f11b3fbe7b25ad52b72cb5caff67934f69015a4263ffb5";
    let nonce = 0;
    let identitySignature;
    let identitySignature2;
    let dataSignature1;
    let dataSignature2;

    before (async function () {
        [owner, addr1, addr2, addr3, addr4, ...addrs] = await ethers.getSigners();

        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await  _identityToken.deploy("Rejuve Identities","RI");

        _dataMgt = await ethers.getContractFactory("DataManagement");
        dataMgt = await _dataMgt.deploy(identityToken.address);

        _productNFT = await ethers.getContractFactory("ProductNFT"); 
        productNFT = await _productNFT.deploy("Rejuve Products","RP", identityToken.address, dataMgt.address);

        ++nonce;
        identitySignature = await _getSign.getSignForIdentity(owner.address, "/tokenURIHere", nonce, identityToken.address, owner);   
        await identityToken.createIdentity(identitySignature, owner.address, "/tokenURIHere", nonce);

        ++nonce;
        identitySignature2 = await _getSign.getSignForIdentity(addr1.address, "/tokenURIHere", nonce, identityToken.address, addr1);   
        await identityToken.createIdentity(identitySignature2, addr1.address, "/tokenURIHere", nonce);

        // submit data on the behalf of data owner 1
        ++nonce;
        dataSignature1 = await _getSign.getSignForData(owner.address, dataHash1, nonce, dataMgt.address, owner);
        await dataMgt.connect(addr2).submitData(owner.address, dataSignature1, dataHash1, nonce);

        // submit data on the behalf of data owner 2
        ++nonce;
        dataSignature2 = await _getSign.getSignForData(addr1.address, dataHash2, nonce, dataMgt.address,addr1);
        await dataMgt.connect(addr2).submitData(addr1.address, dataSignature2, dataHash2, nonce);
    }); 

    it("Should revert if contract is paused", async function () {

        await productNFT.pause();
        await expect(productNFT.connect(addr2).createProduct(
            3,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("Pausable: paused");
    });

    it("Should revert if product creator is not registered", async function () {
        await productNFT.unpause();
        await expect(productNFT.connect(addr2).createProduct(
            3,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Not Registered");
    });

    it("Should revert if product creator is using someone else ID", async function () {
    
        await expect(productNFT.connect(addr1).createProduct(
            1,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Caller is not owner of lab ID");
    });

    it("Should revert if data & credits array length is not equal", async function () {

        let creatorID = await identityToken.getOwnerIdentity(addr1.address);

        await expect(productNFT.connect(addr1).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20,30]
        )).to.be.revertedWith("REJUVE: Not equal length");
    });

    it("Should revert if all given data is not permitted to use", async function () {
   
        let creatorID = await identityToken.getOwnerIdentity(addr1.address);
        await expect(productNFT.connect(addr1).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted");
    });

    it("Should revert if one of all given data hashes is not permitted to use", async function () {

        ++nonce;
        let identitySignature3 = await _getSign.getSignForIdentity(addr4.address, "/tokenURIHere", nonce, identityToken.address, addr4);   
        await identityToken.createIdentity(identitySignature3 , addr4.address, "/tokenURIHere", nonce)

        ++nonce;
        let expiration = 2;
        expiration = expiration * 24 * 60 * 60;

        // Get permission from data owner 1
        let permissionSign = _getSign.getSignForPermission(owner.address, 3, dataHash1, 100, nonce, expiration, dataMgt.address, owner);
        await dataMgt.connect(addr4).getPermission(owner.address, permissionSign, dataHash1, 3, 100, nonce, expiration);

        let creatorID = await identityToken.getOwnerIdentity(addr4.address);
        // Product Creation by lab
        await expect(productNFT.connect(addr4).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted");   

    });

    it("Should create product", async function () {

        let i = 0; 
        ++nonce;
        let expiration = 2;
        expiration = expiration * 24 * 60 * 60;

        // Get permission from data owner 1
        let permissionSign = _getSign.getSignForPermission(owner.address, 3, dataHash1, 100, nonce, expiration, dataMgt.address, owner);
        await dataMgt.connect(addr4).getPermission(owner.address, permissionSign, dataHash1, 3, 100, nonce, expiration);

        // Get permission from data owner 2
        ++nonce;
        let permissionSign2 = _getSign.getSignForPermission(addr1.address, 3, dataHash2, 100, nonce, expiration, dataMgt.address, addr1);
        await dataMgt.connect(addr4).getPermission(addr1.address, permissionSign2, dataHash2, 3, 100, nonce, expiration);

        let creatorID = await identityToken.getOwnerIdentity(addr4.address);
        // Product Creation by lab (addr4)
        await productNFT.connect(addr4).createProduct(
            creatorID,
            productUID,
            "/ProductURI",
            [dataHash1,
            dataHash2],
            [10,20]
        ); 

        expect (await productNFT.ownerOf(productUID)).to.equal(addr4.address);
        expect (await productNFT.tokenURI(productUID)).to.equal("/ProductURI");    

        let arr = await productNFT.getProductToData(productUID);
        expect (arr.length).to.equal(2);       
        expect (arr[i]).to.equal(dataHash1);
        expect (arr[++i]).to.equal(dataHash2);
        
        expect (await productNFT.getDataCredit(dataHash1, productUID)).to.equal(10);
        expect (await productNFT.getDataCredit(dataHash2, productUID)).to.equal(20);
    
        expect (await productNFT.getDataOwnerAddress(dataHash1)).to.equal(owner.address);    
        expect (await productNFT.getDataOwnerAddress(dataHash2)).to.equal(addr1.address);    
    });


    it("Should revert if called by user other than product owner", async function () {
        // New data submission by addr2 on the behalf of data owner 1
        ++nonce;
        let newDataSignature = await _getSign.getSignForData(owner.address, newDataHash, nonce, dataMgt.address, owner);
        await dataMgt.connect(addr2).submitData(owner.address, newDataSignature, newDataHash, nonce);
 
        // Get permission by Lab to use new data hash for an existing product
        let expiration = 2;
        expiration = expiration * 24 * 60 * 60;
        ++nonce;
        let permissionSign = _getSign.getSignForPermission(owner.address, 3, newDataHash, 100, nonce, expiration, dataMgt.address, owner);
        await dataMgt.connect(addr4).getPermission(owner.address, permissionSign, newDataHash, 3, 100, nonce, expiration);
 
        await expect (productNFT.linkNewData(productUID, [newDataHash], [30]))
        .to.be.revertedWith("REJUVE: Only Product Creator");  
    });

    it("Should link new data to existing product", async function () {
        // New data submission by addr2 on the behalf of data owner 1
        ++nonce;
        let newDataSignature = await _getSign.getSignForData(owner.address, newDataHash, nonce, dataMgt.address, owner);
        await dataMgt.connect(addr2).submitData(owner.address, newDataSignature, newDataHash, nonce);

        // Get permission by Lab to use new data hash for an existing product
        let expiration = 2;
        expiration = expiration * 24 * 60 * 60;
        ++nonce;
        let permissionSign = _getSign.getSignForPermission(owner.address, 3, newDataHash, 100, nonce, expiration, dataMgt.address, owner);
        await dataMgt.connect(addr4).getPermission(owner.address, permissionSign, newDataHash, 3, 100, nonce, expiration);

        // Link new data by product owner
        await productNFT.connect(addr4).linkNewData(productUID, [newDataHash], [30]);
        let dataArray2 = await productNFT.getProductToData(productUID);

        let dataArray = [dataHash1, dataHash2, newDataHash];
        expect (dataArray2.length).to.equal(3);

        for (i=0; i < dataArray2.length; i++){
            expect (dataArray2[i]).to.equal(dataArray[i]);
        }       
    });
})