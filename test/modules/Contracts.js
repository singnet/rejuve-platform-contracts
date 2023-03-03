let productShard;
let shardContract;

function setContractAddress(contract, address) {
    shardContract = contract;
    productShard = address;
}

function getAddress() {
    return productShard;
}

function getContract() {
    return shardContract;
}

module.exports.setContractAddress = setContractAddress;
module.exports.getAddress = getAddress;
module.exports.getContract = getContract;