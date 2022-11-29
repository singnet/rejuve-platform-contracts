const hre = require("hardhat"); // using hardhat as library
let identityTokenContract = "0x4A01D66942C4aE330DF52fE2AEAD9921935575A3";

async function main() {

    await hre.run('compile');
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contract with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const _dataMgt = await ethers.getContractFactory("DataManagement");
    const dataMgt = await _dataMgt.deploy(identityTokenContract);

    console.log("Data Management contract address:", dataMgt.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });