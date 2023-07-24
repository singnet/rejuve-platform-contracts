const { expect } = require("chai");
let identity = require("./modules/CreateIdentity");
let data = require("./modules/DataSubmission");
// let deploy = require("./modules/DeployContract");
let _getSign = require ('./modules/GetSign');

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
    let signer;
    let addrs;
    let productUID = 200;
    let nonce = 1;
    let creatorID;
    let expiration = 2;
    expiration = expiration * 24 * 60 * 60;
    let signForProduct;

    let dataHash1 =
    "0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b";
    let dataHash2 =
    "0x7012f98e24c6b2f609d365c959c99a9bc691d6939cc7162e679fb1226697a56b";
    let newDataHash =
    "0x1988284e7250800b37f11b3fbe7b25ad52b72cb5caff67934f69015a4263ffb5";

    let zero_address = "0x0000000000000000000000000000000000000000";

    const kycDataHash= "7924fbcf9a7f76ca5412304f2bf47e326b638e9e7c42ecad878ed9c22a8f1428";
    const kyc = "0x" + kycDataHash;

    let dataHashes;
    let dataHashConcatenated;
    let newDataHashes;
    let newDataHashConcatenated;

    before (async function () {
        [rejuveAdmin, dataOwner1, dataOwner2, sponsor, lab, signer, ...addrs] = await ethers.getSigners();

    //-------------------- Deploy contracts ----------------------/

        _identityToken = await ethers.getContractFactory("IdentityToken");
        identityToken = await  _identityToken.deploy("Rejuve Identities","RI");

        _dataMgt = await ethers.getContractFactory("DataManagement");
        dataMgt = await _dataMgt.deploy(identityToken.address);

        _productNFT = await ethers.getContractFactory("ProductNFT"); 
        productNFT = await _productNFT.deploy(
            "Rejuve Products",
            "RP", 
            signer.address,
            identityToken.address, 
            dataMgt.address
        );

        // Get concatenated hash 
        dataHashes = [dataHash1, dataHash2];
        dataHashConcatenated = await _getSign.concatenatedHash(dataHashes);

        // Get concatenated hash for new data
        newDataHashes = [newDataHash];
        newDataHashConcatenated = await _getSign.concatenatedHash(newDataHashes);

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

    //------------------------ Initial setting tests --------------------//
 
    it("Should set product collection name", async function () {
        expect (await productNFT.name()).to.equal("Rejuve Products");
    })

    it("Should set product collection symbol", async function () {
        expect (await productNFT.symbol()).to.equal("RP");
    })

    //---------------------- Pause & unpause -----------------------------//

    it("Should revert if contract paused by user other than owner", async function () {
        await expect(productNFT.connect(sponsor).pause())
        .to.be.revertedWith("REJUVE: Must have pauser role to pause");
    })

    it("Should revert if contract is paused", async function () {
        await productNFT.pause();
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );
        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("Pausable: paused");
        expect (await productNFT.paused()).to.equal(true);
        ++nonce;
    });

    it("Should revert if contract unpaused by user other than owner", async function () {
        await expect(productNFT.connect(sponsor).unpause())
        .to.be.revertedWith("REJUVE: Must have a role to unpause");
    })

    it("Should unpause contract", async function () {
        await productNFT.unpause();
        expect (await productNFT.paused()).to.equal(false);
    })

    //--------------------- Registration -----------------------------------//

    it("Should revert if product creator is not registered", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );      
        await expect(productNFT.connect(sponsor).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10,20]
        )).to.be.revertedWith("REJUVE: Not Registered");
        ++nonce;
    })
  
    it("Should revert if data & credits array length is not equal", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );

        //creatorID = await identityToken.getOwnerIdentity(lab.address);
        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20, 30]
        )).to.be.revertedWith("REJUVE: Not equal length");
        ++nonce;
    })    

    //---------------------- Signature Validation -------------------------//

    it("Should revert if signer address is zero", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            zero_address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Signer can not be zero");
        ++nonce;
    })

    it("Should revert if invalid signer", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            sponsor.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Invalid signer");
        ++nonce;
    })

    it("Should revert if invalid signature", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            sponsor.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Invalid signature of signer");
        ++nonce;
    })

    //---------------------- Data permission -------------------------------//

    it("Should revert if all given data is not permitted to use", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );
        
        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted");
        ++nonce;
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

        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );

        //Product Creation by lab
        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Data Not Permitted"); 
        ++nonce;
    })

    //--------------------- Create product --------------------------//

    it("Should create product", async function () {
        // Get lab token ID (data requestor ID)
        let labID = await identityToken.getOwnerIdentity(lab.address);
        //Get permission from data owner 2
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
        );
        
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            dataHashConcatenated,
            [10,20],
            lab.address,
            productNFT.address,
            signer
        );
        //Product Creation by lab
        await productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        ); 
        expect (await productNFT.ownerOf(productUID)).to.equal(lab.address);
        expect (await productNFT.tokenURI(productUID)).to.equal("/ProductURI");    
        expect (await productNFT.balanceOf(lab.address)).to.equal(1);
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

    it("Should revert if using same signature again when creating a product", async function () {
        await expect(productNFT.connect(lab).createProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [dataHash1,
            dataHash2],
            [10, 20]
        )).to.be.revertedWith("REJUVE: Signature used already"); 
        ++nonce;           
    })

    //------------------ Link New data to existing product --------------//   


    it("Should revert if called by user other than product owner", async function () {
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );
        await expect(productNFT.linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
            ))
        .to.be.revertedWith("REJUVE: Only Product Creator"); 
        ++nonce; 
    })

    it("Should revert if trying to link data when contract is paused", async function () {
        await productNFT.pause();
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );
        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
        ))
        .to.be.revertedWith("Pausable: paused");  
        ++nonce;
    })

    it("Should revert if data length is not equal", async function () {
        await productNFT.unpause();
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );
        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20,30]
        ))
        .to.be.revertedWith("REJUVE: Not equal length");  
        ++nonce;   
    });

    it("Should revert if signer address is zero when linking new data", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            zero_address,
            signForProduct,
            [newDataHash], 
            [20]
        )).to.be.revertedWith("REJUVE: Signer can not be zero");
        ++nonce;
    })

    it("Should revert if invalid signer when linking new data", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            sponsor.address,
            signForProduct,
            [newDataHash], 
            [20]
        )).to.be.revertedWith("REJUVE: Invalid signer");
    })

    it("Should revert if invalid signature when linking new data", async function () {
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            sponsor.address,
            productNFT.address,
            signer
        );

        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
        )).to.be.revertedWith("REJUVE: Invalid signature of signer");
        ++nonce;
    })

    it("Should revert if data is not permitted when linking new data", async function () {
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );
        console.log("Signature in test case ", signForProduct);
        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
        ))
        .to.be.revertedWith("REJUVE: Data Not Permitted");     
        ++nonce;
    });

    it("Should link new data to existing product", async function () {

        // Get lab token ID (data requestor ID)
        let labID = await identityToken.getOwnerIdentity(lab.address);

        // Get permission for new data hash from data owner 2
        await data.getAccessPermission(
            dataOwner2.address,
            labID,
            newDataHash,
            productUID,
            expiration,
            dataMgt.address,
            dataOwner2,
            lab,
            dataMgt
        );
        
        // Get sign on credit scores from an authorized signer 
        signForProduct = await _getSign.getSignForProduct(
            productUID,
            nonce,
            "/ProductURI",
            signer.address,
            newDataHashConcatenated,
            [20],
            lab.address,
            productNFT.address,
            signer
        );

        // Link new data by product owner
        await productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
        );

        let dataArray2 = await productNFT.getProductToData(productUID);
        let dataArray = [dataHash1, dataHash2, newDataHash];
        expect (dataArray2.length).to.equal(3);

        for (let i=0; i < dataArray2.length; i++){
            expect (dataArray2[i]).to.equal(dataArray[i]);
        }       
    });

    it("Should revert if using same signature again when linking new data", async function () {
        await expect(productNFT.connect(lab).linkNewData(
            productUID, 
            nonce,
            "/ProductURI",
            signer.address,
            signForProduct,
            [newDataHash], 
            [20]
        )).to.be.revertedWith("REJUVE: Signature used already");
    })

    //--------------------------- Interface -----------------------//

    // Test case
    it('should return true for supported interface', async () => {
        const interfaceId = ethers.utils.id('yourInterfaceId');
        const result = await productNFT.supportsInterface(interfaceId);
        console.log(result);
    
        //assert.isTrue(result, 'Expected the function to return true');
    });
    
    // it('should return false for unsupported interface', async () => {
    //     const interfaceId = ethers.utils.id('unsupportedInterfaceId');
    //     const result = await yourContract.supportsInterface(interfaceId);
    
    //     assert.isFalse(result, 'Expected the function to return false');
    // });
    
})    




