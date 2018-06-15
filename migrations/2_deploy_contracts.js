const Arbitration = artifacts.require('./Arbitration.sol');
const ArbitrationFactory = artifacts.require('./ArbitrationFactory.sol');
const JURToken = artifacts.require('./JURToken.sol');

const Web3 = require('web3');
web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

let signJURFunction = {
  name: 'signJUR',
  type: 'function',
  inputs: [{
      type: 'address',
      name: '_sender'
    }]
};
let signJUR = web3.eth.abi.encodeFunctionSignature(signJURFunction);

let proposeAmendmentJURFunction = {
  name: 'proposeAmendmentJUR',
  type: 'function',
  inputs: [{
      type: 'address',
      name: '_sender'
    },{
      type: 'uint256[]',
      name: '_dispersal'
    },{
      type: 'uint256[]',
      name: '_funding'
    },{
      type: 'bytes32',
      name: '_agreementHash'
    }]
};
let proposeAmendmentJUR = web3.eth.abi.encodeFunctionSignature(proposeAmendmentJURFunction);

let agreeAmendmentJURFunction = {
  name: 'agreeAmendmentJUR',
  type: 'function',
  inputs: [{
      type: 'address',
      name: '_sender'
    }]
};
let agreeAmendmentJUR = web3.eth.abi.encodeFunctionSignature(agreeAmendmentJURFunction);

let disputeJURFunction = {
  name: 'disputeJUR',
  type: 'function',
  inputs: [{
      type: 'address',
      name: '_sender'
    },{
      type: 'uint256',
      name: '_voteAmount'
    },{
      type: 'uint256[]',
      name: '_dispersal'
    }]
};
let disputeJUR = web3.eth.abi.encodeFunctionSignature(disputeJURFunction);

let voteJURFunction = {
  name: 'voteJUR',
  type: 'function',
  inputs: [{
      type: 'address',
      name: '_sender'
    },{
      type: 'address',
      name: '_voteAddress'
    },{
      type: 'uint256',
      name: '_voteAmount'
    }]
};
let voteJUR = web3.eth.abi.encodeFunctionSignature(voteJURFunction);

module.exports = function (deployer, network, accounts) {

  return deployer.deploy(JURToken, [signJUR, proposeAmendmentJUR, agreeAmendmentJUR, disputeJUR, voteJUR]).then(() => {
    return JURToken.deployed().then((jurToken) => {
      return deployer.deploy(ArbitrationFactory, JURToken.address);
    });
  });

}
