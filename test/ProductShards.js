const { expect } = require("chai");
let _getSign = require("./modules/GetSign");
let deploy = require("./modules/DeployContract");
let identity = require("./modules/CreateIdentity");
let data = require("./modules/DataSubmission");

describe("Product shards - 1155", function () {
  let identityToken;
  let dataMgt;
  let productNFT;
  let _productShards;
  let productShards;
  let dataOwner1;
  let dataOwner2;
  let rejuveSponsor;
  let lab;
  let labID;
  let rejuveAdmin;
  let clinic;
  let dataOwner3; // new data owner
  let addrs;

  let dataHash1 =
    "0x622b1092273fe26f6a2c370a5c34a690337e7f802f2fa5006b40790bd3f7d69b";
  let dataHash2 =
    "0x7012f98e24c6b2f609d365c959c99a9bc691d6939cc7162e679fb1226697a56b";
  let newDataHash =
    "0x1988284e7250800b37f11b3fbe7b25ad52b72cb5caff67934f69015a4263ffb5";

  let productUID = 200;
  let expiration = 2;
  expiration = expiration * 24 * 60 * 60;
  const shareTarget = 100;
  const shareDecimal = 2;
  const calculatedTarget = shareTarget * 10 ** shareDecimal;

  let lockPeriod = 2;
  lockPeriod = lockPeriod * 60 * 60;

  before(async function () {
    [
      dataOwner1,
      dataOwner2,
      rejuveSponsor,
      addr3,
      lab,
      rejuveAdmin,
      clinic,
      dataOwner3,
      ...addrs
    ] = await ethers.getSigners();

    //-------------------- Deploy contracts ----------------------/

    let contractInstance = await deploy.deployAll(
      lab,
      rejuveAdmin.address,
      100
    );
    identityToken = contractInstance[0];
    dataMgt = contractInstance[1];
    productNFT = contractInstance[2];

    _productShards = await ethers.getContractFactory("ProductShards");
    productShards = await _productShards.deploy(
      "/rejuveshards",
      productNFT.address
    );

    //------------------ Create Identities -------------------------/

    // Create identity by rejuve sponsor for data owner 1
    await identity.createIdentity(
      dataOwner1.address,
      "/tokenURIHere",
      identityToken.address,
      dataOwner1,
      rejuveSponsor,
      identityToken
    );

    // Create identity by rejuve sponsor for data owner 2
    await identity.createIdentity(
      dataOwner2.address,
      "/tokenURIHere",
      identityToken.address,
      dataOwner2,
      rejuveSponsor,
      identityToken
    );

    // Create identity by rejuve sponsor for data owner 3
    await identity.createIdentity(
      dataOwner3.address,
      "/tokenURIHere",
      identityToken.address,
      dataOwner3,
      rejuveSponsor,
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
      rejuveSponsor,
      dataMgt
    );

    // submit data on the behalf of data owner 2
    await data.submitDataHash(
      dataOwner2.address,
      dataHash2,
      dataMgt.address,
      dataOwner2,
      rejuveSponsor,
      dataMgt
    );

    // submit data on the behalf of data owner 3
    await data.submitDataHash(
      dataOwner3.address,
      newDataHash,
      dataMgt.address,
      dataOwner3,
      rejuveSponsor,
      dataMgt
    );

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
    );

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
    );
  });

  //----------------- Create Product -------------------------------

  it("Should create product ", async function () {
    // Product Creation by lab (lab)
    await productNFT
      .connect(lab)
      .createProduct(
        labID,
        productUID,
        "/ProductURI",
        [dataHash1, dataHash2],
        [10, 20]
      );

    expect(await productNFT.ownerOf(productUID)).to.equal(lab.address);
    expect(await productNFT.tokenURI(productUID)).to.equal("/ProductURI");
  });

  //----------------- Create Shards -------------------------------

  it("Should create 1155 based shards", async function () {
    await productShards.distributeInitialShards(
      productUID,
      100,
      30,
      lockPeriod,
      30,
      20,
      lab.address,
      rejuveAdmin.address
    );

    expect(await productShards.totalShardSupply(productUID)).to.equal(48);
    expect(await productShards.targetSupply(productUID)).to.equal(100);
    expect(await productShards.initialPercent(productUID)).to.equal(30);
    expect(await productShards.rejuvePercent(productUID)).to.equal(20);
    console.log("Lock period ::", await productShards.lockPeriod(productUID));
  });

//--------------------------------- Future Shards ------------------------------------//

  it("Should create future shards", async function () {
    await productShards.distributeFutureShards(
      productUID,
      40,
      [30, 50],
      [dataOwner3.address, clinic.address]
    );

    expect(await productShards.futurePercent(productUID)).to.equal(40);
    expect(await productShards.totalShardSupply(productUID)).to.equal(86);  
  })

//------------------------------------- Remaining shards ------------------------------//


  it("Should create remaining shards  ", async function () {
    await productShards.mintRemainingShards(
      productUID,
      rejuveAdmin.address
    );
  })

  //----------------------------------- Transfer shard ---------------------------------//

  it("Should transfer shards", async function () {
    await productShards.safeTransferFrom(
      dataOwner1.address,
      dataOwner3.address,
      1,
      2,
      "0x00"
    );
  });

  it("Should lock shards", async function () {
  
    await expect( 
      productShards.connect(dataOwner2).safeTransferFrom(
        dataOwner2.address,
        dataOwner3.address,
        0,
        2,
        "0x00"
      )).to.be.revertedWith("REJUVE: Cannot sale 50% of shards before locking period");
  });

  // it("Should unlock shards to be tranfered", async function () {
  //   //console.log("Block timestample " , await productShards.block.timestamp());
    
  //   // await productShards.connect(dataOwner2).safeTransferFrom(
  //   //   dataOwner2.address,
  //   //   dataOwner3.address,
  //   //   0,
  //   //   2,
  //   //   "0x00"
  //   // );
  // });





  it("Should revert if caller is not owner or an approved address", async function () {
    await expect(
      productShards.safeTransferFrom(
        rejuveSponsor.address,
        dataOwner3.address,
        1,
        2,
        "0x00"
      )
    ).to.be.revertedWith("ERC1155: caller is not owner nor approved");
  });

  it("Should approve another address", async function () {
    await productShards
      .connect(dataOwner2)
      .setApprovalForAll(rejuveSponsor.address, true);
    expect(
      await productShards.isApprovedForAll(
        dataOwner2.address,
        rejuveSponsor.address
      )
    ).to.equal(true);

    await productShards
      .connect(rejuveSponsor)
      .safeTransferFrom(dataOwner2.address, dataOwner3.address, 1, 2, "0x00");

    expect(await productShards.balanceOf(dataOwner3.address, 1)).to.equal(11);
  });

  //----------------------------------- Other ----------------------------------------//

  it("should revert if contract is paused", async function () {
    await productShards.pause();
    expect(await productShards.paused()).to.equal(true);

    await expect(
      productShards.safeTransferFrom(
        dataOwner2.address,
        dataOwner3.address,
        1,
        2,
        "0x00"
      )
    ).to.be.revertedWith("Pausable: paused");
  });

  it("should unpause contract", async function () {
    await productShards.unpause();
    expect(await productShards.paused()).to.equal(false);
  });

  it("Should revert if lock period is zero", async function () {
    await expect(
      productShards.distributeInitialShards(
        productUID,
        100,
        30,
        0,
        30,
        20,
        lab.address,
        rejuveAdmin.address
      )
    ).to.be.revertedWith("REJUVE: Lock period cannot be zero");
  });

  it("Should revert if target supply is zero", async function () {
    await expect(
      productShards.distributeInitialShards(
        productUID,
        0,
        30,
        2,
        30,
        20,
        lab.address,
        rejuveAdmin.address
      )
    ).to.be.revertedWith("REJUVE: Target supply can not be 0");
  });

  it("Should Initial contributor percentage is zero", async function () {
    await expect(
      productShards.distributeInitialShards(
        productUID,
        100,
        30,
        2,
        0,
        20,
        lab.address,
        rejuveAdmin.address
      )
    ).to.be.revertedWith("REJUVE: Initial contributors percent can not be 0");
  });
});
