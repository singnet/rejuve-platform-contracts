const hre = require("hardhat"); // using hardhat as library
let identityTokenContract = "0x4A01D66942C4aE330DF52fE2AEAD9921935575A3";
let dataMgtContract = "0xEb5f4785e2d206D88C0fEf5E12F568e769b4D93A";

async function main() {

    await hre.run('compile');
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contract with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const _productNFT = await ethers.getContractFactory("ProductNFT");
    const productNFT = await _productNFT.deploy("Rejuve Products", "RP", identityTokenContract, dataMgtContract);

    console.log("Product NFT contract address:", productNFT.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });