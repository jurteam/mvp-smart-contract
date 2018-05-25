pragma solidity ^0.4.11;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import './Arbitration.sol';

contract ArbitrationFactory is Ownable {

  event ArbitrationCreated(address indexed _creator, address _arbitration, address indexed _party1, address indexed _party2);

  address public arbitrationToken;
  address[] public arbirations;

  function ArbitrationFactory(address _arbitrationToken) {
    arbitrationToken = _arbitrationToken;
  }

  function createArbitration(address _party1, address _party2, uint256 _party1Amount, uint256 _party2Amount, bytes32 _agreementHash) public {
    //address _jurToken, address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash
    address[] memory parties = new address[](2);
    parties[0] = _party1;
    parties[1] = _party2;
    uint256[] memory dispersal = new uint256[](2);
    dispersal[0] = _party1Amount;
    dispersal[1] = _party2Amount;
    uint256[] memory funding = new uint256[](2);
    funding[0] = _party1Amount;
    funding[1] = _party2Amount;

    address newArbitration = new Arbitration(arbitrationToken, parties, dispersal, funding, _agreementHash);
    arbirations.push(newArbitration);
    ArbitrationCreated(msg.sender, newArbitration, _party1, _party2);
  }

  function generateHash(string _input) constant returns (bytes32) {
    return keccak256(_input);
  }

  function updateTokenAddress(address _arbitrationTokenAddress) onlyOwner {
    arbitrationToken = ERC20(_arbitrationTokenAddress);
  }

}
