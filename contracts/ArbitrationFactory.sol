pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Arbitration.sol";

contract ArbitrationFactory is Ownable {

  event ArbitrationCreated(address indexed _creator, address _arbitration, address indexed _party1, address indexed _party2, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);

  address public jurToken;
  address[] public arbirations;

  constructor(address _jurToken) public {
    jurToken = _jurToken;
  }

  function createArbitration(address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {
    address newArbitration = new Arbitration(jurToken, _parties, _dispersal, _funding, _agreementHash);
    arbirations.push(newArbitration);
    emit ArbitrationCreated(msg.sender, newArbitration, _parties[0], _parties[1], _dispersal, _funding, _agreementHash);
  }

  function changeToken(address _jurToken) onlyOwner public {
    jurToken = _jurToken;
  }

  function generateHash(string _input) pure public returns (bytes32) {
    return keccak256(_input);
  }

  function updateTokenAddress(address _jurTokenAddress) public onlyOwner {
    jurToken = ERC20(_jurTokenAddress);
  }

}
