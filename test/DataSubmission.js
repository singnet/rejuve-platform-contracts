const { expect } = require("chai");

describe("Data Submission Contract", function () {

    let _dataSubmission;
    let dataSubmission;
    let owner;
    let addr1;
    let addr2;
    let addrs;
    let index=0;

    beforeEach(async function () {
        // Get the ContractFactory and Signers here.
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
        _dataSubmission = await ethers.getContractFactory("DataSubmission");
        dataSubmission = await _dataSubmission.deploy("Rejuve Users","RUI");
    }); 

    // test symbol and name later 


    it("Should revert if data contributor not registered", async function () {
        await expect(dataSubmission.submitData("hash here"))
        .to.be.revertedWith("REJUVE: Not Registered");
    });

    it("Data hash should be submitted against caller Id", async function () {
        await dataSubmission.createIdentityToken();
        await dataSubmission.submitData("Data hash here")

        expect(await dataSubmission.getDataByTokenId(dataSubmission.getOwnerId(owner.address),index++))
        .to.equal("0x3a7b912477438d7261fba3f3f6155f489f0e4c0869ddb9cae9e59f93fe3cdc9d");

    });

    it("should revert if lab not registered", async function () {
        await expect(dataSubmission.connect(addr1).requestPermission(
            0,
            "0x3a7b912477438d7261fba3f3f6155f489f0e4c0869ddb9cae9e59f93fe3cdc9d",
            100
        )).to.be.revertedWith("REJUVE: Not Registered");
    });

    it("should revert if caller is not owner of Lab ID", async function () {

        await dataSubmission.connect(addr1).createIdentityToken();
        await dataSubmission.connect(addr2).createIdentityToken();
        await expect(dataSubmission.connect(addr2).requestPermission(
            1,
            "0x3a7b912477438d7261fba3f3f6155f489f0e4c0869ddb9cae9e59f93fe3cdc9d",
            100
        )).to.be.revertedWith("REJUVE: Caller is not owner of Lab ID");
    });


    it("should revert if caller is not owner", async function () {

        await dataSubmission.createIdentityToken(); //data owner
        await dataSubmission.submitData("Data hash here");
        await dataSubmission.connect(addr1).createIdentityToken(); //lab

        await dataSubmission.connect(addr1).requestPermission(
            2,
            "0x3a7b912477438d7261fba3f3f6155f489f0e4c0869ddb9cae9e59f93fe3cdc9d",
            100
        )

        await dataSubmission.connect(addr2).createIdentityToken();
        await expect(dataSubmission.connect(addr2).grantPermission(
            2,
            "0x3a7b912477438d7261fba3f3f6155f489f0e4c0869ddb9cae9e59f93fe3cdc9d",
            100
        )).to.be.revertedWith("REJUVE: Only Data Owner");
    });



});