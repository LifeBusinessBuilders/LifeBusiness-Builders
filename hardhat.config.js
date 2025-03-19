require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.22",
  networks: {
    amoy: {
      url: "https://rpc-amoy.polygon.technology", // Amoy testnet RPC
      accounts: [], // Empty because we will use MetaMask manually
    },
  },
};
