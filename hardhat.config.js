require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require('solidity-coverage');
require('@openzeppelin/test-helpers');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {

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
            runs: 200,
          },
        },
      },
    
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
