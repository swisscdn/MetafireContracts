var HelloWorld = artifacts.require("Arbitrum");

module.exports = function (deployer) {
  deployer.deploy(HelloWorld, "Arbitrum");
  // Additional contracts can be deployed here
};
