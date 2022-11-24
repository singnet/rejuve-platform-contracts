
const { expect } = require("chai");
const { ethers } = require('hardhat');

async function TestTime(days){
    const calculateSec = days * 24 * 60 * 60;
    console.log("Time in sec ", calculateSec);

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    await ethers.provider.send('evm_increaseTime', [calculateSec]);
    await ethers.provider.send('evm_mine');

    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const timestampAfter = blockAfter.timestamp;

    console.log("Time before ", timestampBefore);
    console.log("Time after: ", timestampAfter);

    expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
    expect(timestampAfter).to.be.equal(timestampBefore + calculateSec);
}

module.exports.TestTime = TestTime;