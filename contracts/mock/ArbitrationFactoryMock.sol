pragma solidity ^0.4.11;

import '../ArbitrationFactory.sol';
import './ArbitrationMock.sol';

contract ArbitrationFactoryMock is ArbitrationFactory {

  function ArbitrationFactoryMock(address _arbitrationToken)
    ArbitrationFactory(_arbitrationToken)
  {
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

}
