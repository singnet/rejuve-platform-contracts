let totalDepositAmount = 0;
let percentagePoints = 0;
let withdrawAmount = 0;

async function depositRejuveTokens(rejuveToken, buyer, profitContractAddress, profitContract, productUID, amount) {
    await rejuveToken.connect(buyer).approve(profitContractAddress, amount);
    await profitContract.connect(buyer).deposit(productUID, amount);
    totalDepositAmount += amount;

    return totalDepositAmount;
}

async function calculateEarning(rejuveToken, callerAddress, caller, profitContract, productUID, totalAvailableShards){
    let rejuveBalance = await rejuveToken.balanceOf(callerAddress)
    let shardBalance = await profitContract.connect(caller)._getShardBalance(productUID);
    let percentageContribution = (shardBalance * 100) / totalAvailableShards;
    percentagePoints = Math.trunc(percentageContribution) ;
    percentagePoints = percentagePoints * 100;
 
    let productEarning = await profitContract.getProductEarning(productUID);
    let holderlastPoint = await profitContract.getHolderLastPoint(callerAddress, productUID);

    let userEarning = productEarning - holderlastPoint;
    let amount = (percentagePoints * userEarning) / 10000; // calculate RJV
    amount = Math.trunc(amount);
    withdrawAmount = amount;
    let total = Number (rejuveBalance) + Number (amount);
    return total;
}

async function getContributionPoints() {
    return percentagePoints;
}

async function getWithdrawAmount() {
    return withdrawAmount;
}

module.exports.depositRejuveTokens = depositRejuveTokens;
module.exports.calculateEarning = calculateEarning;
module.exports.getContributionPoints = getContributionPoints;
module.exports.getWithdrawAmount = getWithdrawAmount;