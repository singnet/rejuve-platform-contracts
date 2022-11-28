
const { expect } = require("chai");
const { ethers } = require('hardhat');

let lockPeriod;

async function setLockPeriod(daysLocked) {
    const calculateSec = daysLocked * 24 * 60 * 60;
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    lockPeriod = timestampBefore + calculateSec;

    console.log("lock period ", lockPeriod);
    return lockPeriod;
}

async function checkTimeAfter(daysPassed) {
    const calculateSec = daysPassed * 24 * 60 * 60;

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    await ethers.provider.send('evm_increaseTime', [calculateSec]);
    await ethers.provider.send('evm_mine');

    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const timestampAfter = blockAfter.timestamp;

    console.log("Time after: ", timestampAfter);
    return timestampAfter;

}






// async function TestTime(days){
//     const calculateSec = days * 24 * 60 * 60;
//     console.log("Time in sec ", calculateSec);

//     const blockNumBefore = await ethers.provider.getBlockNumber();
//     const blockBefore = await ethers.provider.getBlock(blockNumBefore);
//     const timestampBefore = blockBefore.timestamp;

//     await ethers.provider.send('evm_increaseTime', [calculateSec]);
//     await ethers.provider.send('evm_mine');

//     const blockNumAfter = await ethers.provider.getBlockNumber();
//     const blockAfter = await ethers.provider.getBlock(blockNumAfter);
//     const timestampAfter = blockAfter.timestamp;

//     console.log("Time before ", timestampBefore);
    

//     //expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
//     //expect(timestampAfter).to.be.equal(timestampBefore + calculateSec);
// }

// module.exports.TestTime = TestTime;
module.exports.setLockPeriod = setLockPeriod;
module.exports.checkTimeAfter = checkTimeAfter;