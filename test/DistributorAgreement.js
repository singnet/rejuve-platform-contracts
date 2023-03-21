const { expect } = require("chai");
let _getSign = require ('./modules/GetSign');

describe("Distributor Agreement Contract", function () {

    let _agreement;
    let agreement;
    let rejuveAdmin;
    let distributor1;
    let distributor2;
    let addrs;
    let nonce = 0;
    let agreementHash = "0x9805b0899794e98a97a8eafec929e7be05545fd5240c18372121c5ddf725e4f6";
    let zero_address = "0x0000000000000000000000000000000000000000";
    
    before(async function () {
        [rejuveAdmin, distributor1, distributor2, ...addrs] = await ethers.getSigners();
        _agreement= await ethers.getContractFactory("DistributorAgreement");
        agreement = await _agreement.deploy();
    });  

    it("Should revert if contract is paused by person other than owner", async function () {
        await expect(agreement.connect(distributor1).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    it("Should revert if contract is paused", async function () {
        await agreement.pause();
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1) 
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 100, 5, 20, nonce))
        .to.be.revertedWith("Pausable: paused");   
    })

    it("Should revert if contract is unpaused by person other than owner", async function () {
        await expect(agreement.connect(distributor1).unpause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    it("Should create business agreement if Rejuve is paying", async function () {
        await agreement.unpause();
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1)
        await agreement.connect(rejuveAdmin).createAgreement(distributor1.address, signature, agreementHash, 101, 100, 5, 20, nonce);
        ++nonce;
    });

    it("Should create business agreement if distributor is paying", async function () {
        let signature = await _getSign.getDistributorSign(distributor2.address, agreement.address, agreementHash,nonce, distributor2)
        await agreement.connect(distributor2).createAgreement(distributor2.address, signature, agreementHash, 101, 500, 5, 20, nonce);
        console.log(`Distributor details: ${await agreement.getDistributorData(distributor2.address)}`);
    });

    it("Should revert if total units are zero ", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1) 
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 0, 5, 20, nonce))
        .to.be.revertedWith("REJUVE: Total units cannot be zero");   
    })

    it("Should revert if unit price is zero ", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1)
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 100, 0, 20, nonce))
        .to.be.revertedWith("REJUVE: Price cannot be zero");      
    })

    it("Should revert if percentage is zero ", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1) 
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 100, 5, 0, nonce))
        .to.be.revertedWith("REJUVE: Percentage cannot be zero");
    })

    it("Should revert if address is 0 ", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash,nonce, distributor1) 
        await expect(agreement.createAgreement(zero_address, signature, agreementHash, 101, 100, 5, 20, nonce))
        .to.be.revertedWith("REJUVE: Zero address");
    })

    it("Should revert if nonce is used already", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash, nonce, distributor1) 
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 100, 5, 20, nonce))
        .to.be.revertedWith("REJUVE: Nonce used already");
        ++nonce;
    })

    it("Should revert if invalid signature", async function () {
        let signature = await _getSign.getDistributorSign(distributor1.address, agreement.address, agreementHash, nonce, distributor2) 
        await expect(agreement.createAgreement(distributor1.address, signature, agreementHash, 101, 100, 5, 20, nonce))
        .to.be.revertedWith("REJUVE: Invalid signature");
    })
})