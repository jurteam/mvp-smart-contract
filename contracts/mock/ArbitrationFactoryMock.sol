pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./ArbitrationMock.sol";
import "../ArbitrationFactory.sol";

contract ArbitrationFactoryMock is ArbitrationFactory {

  constructor(address _jurToken) public
    ArbitrationFactory(_jurToken)
  {

  }

  function createArbitration(address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {
    address newArbitration = new ArbitrationMock(jurToken, _parties, _dispersal, _funding, _agreementHash);
    arbirations.push(newArbitration);
    emit ArbitrationCreated(msg.sender, newArbitration, _parties[0], _parties[1], _dispersal, _funding, _agreementHash);
  }

}
