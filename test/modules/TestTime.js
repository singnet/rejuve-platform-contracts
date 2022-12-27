const { expect } = require("chai");
const { ethers } = require('hardhat');

let lockPeriod;

async function setLockPeriod(daysLocked) {
    const calculateSec = daysLocked * 24 * 60 * 60;
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    lockPeriod = timestampBefore + calculateSec;
    //console.log("lock period ", lockPeriod);
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

    //console.log("Time after: ", timestampAfter);
    return timestampAfter;

}

module.exports.setLockPeriod = setLockPeriod;
module.exports.checkTimeAfter = checkTimeAfter;