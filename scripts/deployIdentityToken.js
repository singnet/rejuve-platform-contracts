const hre = require("hardhat"); // using hardhat as library

async function main() {

    await hre.run('compile');
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contract with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const _identityToken = await ethers.getContractFactory("IdentityToken");
    const identityToken = await _identityToken.deploy("Rejuve Identities", "RI");

    console.log("Identity token contract address:", identityToken.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });