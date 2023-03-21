const { expect } = require("chai");
let productShards = require("./modules/Contracts");
let _getSign = require ('./modules/GetSign');

describe("Shards Marketplace Contract", function () {

    let _shardMarketplace;
    let shardMarketplace;
    let _rejuveToken;
    let rejuveToken;
    let rejuveAdmin;
    let seller1;
    let seller3;
    let seller4;
    let seller5;
    let seller2;
    let buyer2;
    let buyer3;
    let buyer1;
    let addrs;
    let productShardsContract;
    let shardContract;
    let productUID = 200;
    let zero_address = "0x0000000000000000000000000000000000000000";
    let nonce = 1;
    let signature;
    const emptyBytes = '0x';
    
    before(async function () {
        [rejuveAdmin, seller1, seller2, buyer1, seller3, buyer2, seller4, seller5, ...addrs] = await ethers.getSigners();
        productShardsContract = productShards.getAddress();
        shardContract = productShards.getContract();

        _rejuveToken = await ethers.getContractFactory("RejuveTokenTest");
        rejuveToken = await _rejuveToken.deploy("Rejuve Tokens", "RJV");
        
        _shardMarketplace= await ethers.getContractFactory("ShardMarketplace");
        shardMarketplace = await _shardMarketplace.deploy(productShardsContract, rejuveToken.address);
    }); 

    //---------------------- Shards Listing ------------------//

    it("Should revert if contract is paused by a person other than owner", async function () {
        await expect(shardMarketplace.connect(buyer2).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    it("Should revert if try to list when contract is paused", async function () {
        await shardMarketplace.pause();
        await shardContract.connect(seller1).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);

        await expect(shardMarketplace.connect(seller1).listShard(productUID, 50, productIDs[1]))
        .to.be.revertedWith("Pausable: paused");   
    })

    it("Should revert if contract is unpaused by a person other than owner", async function () {
        await expect(shardMarketplace.connect(buyer2).unpause())
        .to.be.revertedWith("Ownable: caller is not the owner");   
    })

    it("Should list shards on marketplace", async function () {
        await shardMarketplace.unpause();
        await shardContract.connect(seller1).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);
        await shardMarketplace.connect(seller1).listShard(productUID, 50, productIDs[1]);

        expect(await shardMarketplace.getShardPrice(seller1.address, productUID))
        .to.equal(50);
    });

    it("Should revert if listing again", async function () {
        let productIDs = await shardContract.getProductIDs(productUID);
        await expect(shardMarketplace.connect(seller1).listShard(productUID, 50, productIDs[1]))
        .to.be.revertedWith("REJUVE: Listed already");
    });

    it("Should revert if not approved", async function () {
        let productIDs = await shardContract.getProductIDs(productUID);
        await expect(shardMarketplace.connect(seller3).listShard(productUID, 100, productIDs[1]))
        .to.be.revertedWith("REJUVE: Not approved");
    });

    it("Should revert if given price is zero", async function () {
        await shardContract.connect(seller3).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);
        await expect(shardMarketplace.connect(seller3).listShard(productUID, 0, productIDs[1]))
        .to.be.revertedWith("Rejuve: Price cannot be zero");
    });

    it("Should revert if seller's shard balance is zero", async function () {
        await shardContract.connect(seller2).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);
        await expect(shardMarketplace.connect(seller2).listShard(productUID, 500, productIDs[1]))
        .to.be.revertedWith("REJUVE: Insufficent balance");
    });

    //---------------- Update lisitng 

    it("Should revert if updating unlisted shards", async function () {
        await expect(shardMarketplace.connect(seller3).updateList(productUID, 100))
        .to.be.revertedWith("REJUVE: Not listed");
    });

    it("Should revert if updating list when contract is paused", async function () {
        await shardMarketplace.pause();
        await expect(shardMarketplace.connect(seller1).updateList(productUID, 200))
        .to.be.revertedWith("Pausable: paused"); 
    });

    it("Should update listing", async function () {
        await shardMarketplace.unpause();
        await shardMarketplace.connect(seller1).updateList(productUID, 200)
        expect(await shardMarketplace.getShardPrice(seller1.address, productUID))
        .to.equal(200);
    });

    it("Should revert if updating with price 0", async function () {
        await expect(shardMarketplace.connect(seller1).updateList(productUID, 0))
        .to.be.revertedWith("REJUVE: Price cannot be zero");
    });

    //---------------- Cancellisitng 

    it("Should revert if trying to cancel an unlisted item", async function () {
        await expect(shardMarketplace.connect(seller3).cancelList(productUID))
        .to.be.revertedWith("REJUVE: Not listed");
    })

    it("Should revert if cancelling a list when contract is paused", async function () {
        await shardMarketplace.pause();
        await expect(shardMarketplace.connect(seller1).cancelList(productUID))
        .to.be.revertedWith("Pausable: paused");
    })

    it("Should allow cancel a listing", async function () {
        await shardMarketplace.unpause();
        await shardMarketplace.connect(seller1).cancelList(productUID);
        expect(await shardMarketplace.getShardPrice(seller1.address, productUID))
        .to.equal(0);

        expect(await shardMarketplace.getLisitingStatus(seller1.address, productUID))
        .to.equal(0);
    })

    it("Should allow listing again", async function () {
        let productIDs = await shardContract.getProductIDs(productUID);
        await shardMarketplace.connect(seller1).listShard(productUID, 50, productIDs[1]);

        expect(await shardMarketplace.getShardPrice(seller1.address, productUID))
        .to.equal(50);

        expect(await shardMarketplace.getLisitingStatus(seller1.address, productUID))
        .to.equal(1);
    });

    it("Should allow listing - list from seller2", async function () {
        await shardContract.connect(seller4).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);
        await shardMarketplace.connect(seller4).listShard(productUID, 40, productIDs[1]);

        expect(await shardMarketplace.getShardPrice(seller4.address, productUID))
        .to.equal(40);

        expect(await shardMarketplace.getLisitingStatus(seller4.address, productUID))
        .to.equal(1);
    });

    it("Should revert if caller has insufficient shard balance to list", async function () {
        await shardContract.connect(buyer1).setApprovalForAll(shardMarketplace.address, true);
        let productIDs = await shardContract.getProductIDs(productUID);
        await expect(shardMarketplace.connect(buyer1).listShard(productUID, 50, productIDs[1]))
        .to.be.revertedWith("REJUVE: Insufficent balance");
    });
    
    //---------------------- Sale Execution ------------------//

    it("Should revert if seller is not listed", async function () {
        signature = await _getSign.getAdminSignForCoupon(rejuveAdmin.address, rejuveAdmin, buyer2.address, shardMarketplace.address, 200, nonce);

        await expect (shardMarketplace.connect(buyer2).buy(productUID, 2, 1, 200, nonce, seller3.address, signature))
        .to.be.revertedWith("REJUVE: Not listed");
    })

    it("Should revert if shard amount is zero", async function () {
        await expect (shardMarketplace.connect(buyer2).buy(productUID, 0, 1, 200, nonce, seller1.address, signature))
        .to.be.revertedWith("REJUVE: Shard amount cannot be zero");
    })

    it("Should revert if seller has insufficient shards", async function () {
        await expect (shardMarketplace.connect(buyer2).buy(productUID, 4, 1, 200, nonce, seller1.address, signature))
        .to.be.revertedWith("REJUVE: Insufficient shard amount");
    })

    it("Should revert if buyer has insufficient RJV to purchase shards", async function () {
        await expect (shardMarketplace.connect(buyer2).buy(productUID, 2, 1, 200, nonce, seller1.address, signature))
        .to.be.revertedWith("REJUVE Insuffient RJV balance");
    })

    it("Should revert if buyer did not approve marketplace to execute RJV transfer", async function () {
        await rejuveToken.transfer(buyer2.address, 200);
        await expect (shardMarketplace.connect(buyer2).buy(productUID, 2, 1, 200, nonce, seller1.address, signature))
        .to.be.revertedWith("REJUVE: Not approved");
    })

    it("Should revert if buying when contract is paused", async function () {
        await shardMarketplace.pause();
        await rejuveToken.connect(buyer2).approve(shardMarketplace.address, 100);
        await expect( shardMarketplace.connect(buyer2).buy(productUID, 2, 1, 200, nonce, seller1.address, signature))
        .to.be.revertedWith("Pausable: paused");
    })

    //---------------- Discounted sales

    it("Should allow buyer to purchase shards at discounted price", async function () {
        await shardMarketplace.unpause();
        await rejuveToken.connect(buyer2).approve(shardMarketplace.address, 100);
        await shardMarketplace.connect(buyer2).buy(productUID, 2, 1, 200, nonce, seller1.address, signature);

        expect(await shardContract.balanceOf(seller1.address, 1)).to.equal(1);
        expect(await shardContract.balanceOf(buyer2.address, 1)).to.equal(12);
        expect(await rejuveToken.balanceOf(seller1.address)).to.equal(98);
        expect(await rejuveToken.balanceOf(buyer2.address)).to.equal(102);
    })

    //---------------- Normal sales

    it("Should allow buyer to purchase shard at normal price", async function () {
        await rejuveToken.connect(buyer2).approve(shardMarketplace.address, 100);
        await shardMarketplace.connect(buyer2).buy(productUID, 1, 1, 0, 0, seller1.address, emptyBytes);

        expect(await shardContract.balanceOf(seller1.address, 1)).to.equal(0);
        expect(await shardContract.balanceOf(buyer2.address, 1)).to.equal(13);
        expect(await rejuveToken.balanceOf(seller1.address)).to.equal(148);
        expect(await rejuveToken.balanceOf(buyer2.address)).to.equal(52);
    })

    it("Should revert if signature is used already", async function () {
        signature = await _getSign.getAdminSignForCoupon(rejuveAdmin.address, rejuveAdmin, buyer2.address, shardMarketplace.address, 200, nonce);
        await rejuveToken.transfer(buyer1.address, 200);
        await rejuveToken.connect(buyer1).approve(shardMarketplace.address, 80);
        await expect(shardMarketplace.connect(buyer1).buy(productUID, 2, 1, 200, nonce, seller4.address, signature))
        .to.be.revertedWith("REJUVE: Signature used already");
    })

    it("Should allow buyer 2 to purchase shard at normal price", async function () {
        ++nonce;
        signature = await _getSign.getAdminSignForCoupon(rejuveAdmin.address, rejuveAdmin, buyer2.address, shardMarketplace.address, 200, nonce);
        await rejuveToken.connect(buyer1).approve(shardMarketplace.address, 80);
        await shardMarketplace.connect(buyer1).buy(productUID, 2, 1, 200, nonce, seller4.address, signature);
        
        expect(await shardContract.balanceOf(seller4.address, 1)).to.equal(10);
        expect(await shardContract.balanceOf(buyer1.address, 1)).to.equal(2);
        expect(await rejuveToken.balanceOf(seller4.address)).to.equal(80);
        expect(await rejuveToken.balanceOf(buyer1.address)).to.equal(120);
    })
})