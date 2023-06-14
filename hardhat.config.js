require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require('solidity-coverage');
require('@openzeppelin/test-helpers');
require('dotenv').config();

//********** Replace KEYs here ***********************
const _ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const _GOERLI_PRIVATE_KEY = process.env.GOERLI_PRIVATE_KEY;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${_ALCHEMY_API_KEY}`,
      accounts: [_GOERLI_PRIVATE_KEY]
    }
  },

  solidity:{ 
    compilers: [
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },

      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],

  },

  gasReporter: {
    currency: 'USD',
    gasPrice: 36,
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 100000,
  }

};