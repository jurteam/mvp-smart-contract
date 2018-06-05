pragma solidity ^0.4.23;

import "../Arbitration.sol";

contract ArbitrationMock is Arbitration {

  event MockBlockNumber(uint256 _blockNumber);
  event MockNow(uint256 _mockedNow);

  uint blockNumber = 0;

  uint mockedNow = 0;

  constructor(address _jurToken, address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public
    Arbitration(_jurToken, _parties, _dispersal, _funding, _agreementHash)
  {

  }

  function getBlockNumber() view internal returns (uint) {
      return blockNumber;
  }

  function setMockedBlockNumber(uint256 _blockNumber) public {
      blockNumber = _blockNumber;
      emit MockBlockNumber(blockNumber);
  }

  function getNow() view internal returns (uint256) {
      return mockedNow;
  }

  function setMockedNow(uint256 _mockedNow) public {
      mockedNow = _mockedNow;
      emit MockNow(mockedNow);
  }

}
