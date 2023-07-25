const { expect } = require("chai");
let productShards = require("./modules/Contracts");
let profitModule = require("./modules/Profit");

describe("Profit Distribution Contract", function () {

    let _profit;
    let profit;
    let _rejuveToken;
    let rejuveToken;
    let rejuveAdmin;
    let distributor1;
    let individualBuyer;
    let lab;
    let clinic;
    let addrs;
    let productShardsContract;
    let shardContract;
    let totalAvailableShards;
    let totalAmount;
    let dataowner1; 
    let dataowner2;
    let dataowner3;
    let productUID = 200;
    let amountLeft = 0;
    
    before(async function () {
        [rejuveAdmin, dataowner1, distributor1, individualBuyer, lab, dataowner2, clinic, dataowner3, ...addrs] = await ethers.getSigners();
        _rejuveToken = await ethers.getContractFactory("RejuveTokenTest");
        rejuveToken = await _rejuveToken.deploy("Rejuve Tokens", "RJV");

        await rejuveToken.transfer(distributor1.address, 300);
        await rejuveToken.transfer(individualBuyer.address, 200);
        
        productShardsContract = productShards.getAddress();
        shardContract = productShards.getContract();
        totalAvailableShards = await shardContract.totalShardSupply(productUID);

        _profit= await ethers.getContractFactory("ProfitDistribution");
        profit = await _profit.deploy(rejuveToken.address, productShardsContract);
    });  
        
    it("Should revert if 0 earning", async function () {
        await expect(profit.withdraw(productUID))
        .to.be.revertedWith("REJUVE: No product earning");
    })

    it("Should revert if contract is paused by person other than owner", async function () {
        await expect(profit.connect(dataowner1).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    it("Should revert if contract is paused", async function () {
        await profit.pause();
        await expect(profitModule.depositRejuveTokens(rejuveToken, individualBuyer, profit.address, profit, productUID, 50 ))
        .to.be.revertedWith("Pausable: paused");   
    })

    it("Should revert if contract is unpaused by person other than owner", async function () {
        await expect(profit.connect(dataowner1).unpause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    //----- Deposit RJV tokens 

    it("Should receive RJV tokens", async function () {
        await profit.unpause();
        //-- RJV tokens deposited by an Individual buyer ---
        totalAmount = await profitModule.depositRejuveTokens(rejuveToken, individualBuyer, profit.address, profit, productUID, 50 );
       
        //-- RJV tokens deposited by a Distributor ----
        totalAmount = await profitModule.depositRejuveTokens(rejuveToken, distributor1, profit.address, profit, productUID, 50);

        //-- RJV tokens deposited by a Rejuve Admin ----
        totalAmount = await profitModule.depositRejuveTokens(rejuveToken, rejuveAdmin, profit.address, profit, productUID, 200);

        expect(await rejuveToken.balanceOf(profit.address)).to.equal(totalAmount);
        expect(await profit.getProductEarning(productUID)).to.equal(totalAmount);
    })

    it("Should revert if deposited amount is zero", async function () {
        await expect(profit.connect(rejuveAdmin).deposit(productUID, 0))
        .to.be.revertedWith("REJUVE: Zero amount");
    })

    //----- Claim earning by shard holders 

    it("Should claim profit by Rejuve platform", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, rejuveAdmin.address, rejuveAdmin, profit, productUID, totalAvailableShards); 
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.withdraw(productUID); 

        expect (await rejuveToken.balanceOf(rejuveAdmin.address)).to.equal(callerEarning);
        expect (await profit.getHolderLastPoint(rejuveAdmin.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })

    it("Should revert if tries to withdraw again", async function () {
        await profitModule.calculateEarning(rejuveToken, rejuveAdmin.address, rejuveAdmin, profit, productUID, totalAvailableShards); 
        await expect(profit.connect(rejuveAdmin).withdraw(productUID))
        .to.be.revertedWith("REJUVE: No user earning");
    })

    it("Should claim profit by Clinic", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, clinic.address, clinic, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(clinic).withdraw(productUID); 

        expect (await rejuveToken.balanceOf(clinic.address)).to.equal(callerEarning); 
        expect (await profit.getHolderLastPoint(clinic.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
   
    })

    it("Should claim profit by Data owner 1", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, dataowner1.address, dataowner1, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(dataowner1).withdraw(productUID);
        
        expect (await rejuveToken.balanceOf(dataowner1.address)).to.equal(callerEarning); 
        expect (await profit.getHolderLastPoint(dataowner1.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
   
    })

    it("Should claim profit by Data owner 2", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, dataowner2.address, dataowner2, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID);
        await profit.connect(dataowner2).withdraw(productUID);  

        expect (await rejuveToken.balanceOf(dataowner2.address)).to.equal(callerEarning);   
        expect (await profit.getHolderLastPoint(dataowner2.address, productUID)).to.equal(await profit.getProductEarning(productUID));  
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })

    it("Should claim profit by data owner 3", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, dataowner3.address, dataowner3, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(dataowner3).withdraw(productUID); 

        expect (await rejuveToken.balanceOf(dataowner3.address)).to.equal(callerEarning);
        expect (await profit.getHolderLastPoint(dataowner3.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);

        amountLeft = await rejuveToken.balanceOf(profit.address);
        console.log("Product balance now ", await rejuveToken.balanceOf(profit.address));
    })
    
    it("Should revert if caller has no product shards", async function () {
        await expect(profit.connect(distributor1).withdraw(productUID))
        .to.be.revertedWith("REJUVE: No shard balance");
    })

    // it("Should revert if contribution point is zero", async function () {
    //     await expect(profit.connect(distributor1).withdraw(productUID))
    //     .to.be.revertedWith("REJUVE: Zero contribution");
    // })

    //----- Deposit some amount again

    it("Should receive RJV tokens from individual buyer again", async function () {
        totalAmount = await profitModule.depositRejuveTokens(rejuveToken, individualBuyer, profit.address, profit, productUID, 50 );
        let currentBalance = Number(await profit.getProductEarning(productUID)) - Number(await profit.getTotalWithdrawal(productUID));

        expect(await rejuveToken.balanceOf(profit.address)).to.equal(currentBalance);
        expect(await profit.getProductEarning(productUID)).to.equal(totalAmount);
    })

    //----- Claim earning again by shard holders

    it("Should claim profit by Rejuve platform again", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, rejuveAdmin.address, rejuveAdmin, profit, productUID, totalAvailableShards); 
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.withdraw(productUID); 

        expect (await rejuveToken.balanceOf(rejuveAdmin.address)).to.equal(callerEarning);
        expect (await profit.getHolderLastPoint(rejuveAdmin.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })

    it("Should revert if tries to withdraw again", async function () {
        await profitModule.calculateEarning(rejuveToken, rejuveAdmin.address, rejuveAdmin, profit, productUID, totalAvailableShards); 
        await expect(profit.connect(rejuveAdmin).withdraw(productUID))
        .to.be.revertedWith("REJUVE: No user earning");
    })

    it("Should claim profit by Clinic again", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, clinic.address, clinic, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(clinic).withdraw(productUID); 
    
        expect (await rejuveToken.balanceOf(clinic.address)).to.equal(callerEarning); 
        expect (await profit.getHolderLastPoint(clinic.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })

    //-- Lab withdrawal first time
    it("Should claim profit by lab again", async function () {
        let callerEarning = await profitModule.calculateEarning(rejuveToken, lab.address, lab, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(lab).withdraw(productUID);  

        console.log("Lab b :", await rejuveToken.balanceOf(lab.address));

        expect (await rejuveToken.balanceOf(lab.address)).to.equal(callerEarning); 
        expect (await profit.getHolderLastPoint(lab.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })

    it("Should revert if trying withdraw when contract is paused", async function () {
        await profit.pause();
        await profitModule.calculateEarning(rejuveToken, dataowner1.address, dataowner1, profit, productUID, totalAvailableShards);
    
        await expect(profit.connect(dataowner1).withdraw(productUID))
        .to.be.revertedWith("Pausable: paused");
    })

    it("Should claim profit by data owner again", async function () {
        await profit.unpause();
        let callerEarning = await profitModule.calculateEarning(rejuveToken, dataowner1.address, dataowner1, profit, productUID, totalAvailableShards);
        let previousWithdrawal= await profit.getTotalWithdrawal(productUID); 
        await profit.connect(dataowner1).withdraw(productUID);  

        expect (await rejuveToken.balanceOf(dataowner1.address)).to.equal(callerEarning); 
        expect (await profit.getHolderLastPoint(dataowner1.address, productUID)).to.equal(await profit.getProductEarning(productUID));
        let totalWithdrawal = Number (previousWithdrawal) + Number (await profitModule.getWithdrawAmount());
        expect (await profit.getTotalWithdrawal(productUID)).to.equal(totalWithdrawal);
    })
})
