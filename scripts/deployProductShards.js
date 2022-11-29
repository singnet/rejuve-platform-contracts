const hre = require("hardhat"); // using hardhat as library
let productNFTContract = "0x763E769AAd4dCba498D44c1872a4b13cbFf41198";

async function main() {

    await hre.run('compile');
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contract with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const _productShards = await ethers.getContractFactory("TransferShards");
    const productShards = await _productShards.deploy("/rejuveshards", productNFTContract);

    console.log("Product shards contract address:", productShards.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });