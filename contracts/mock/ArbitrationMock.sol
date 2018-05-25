pragma solidity ^0.4.11;

import "../Arbitration.sol";

contract ArbitrationMock is Arbitration {

  event MockBlockNumber(uint256 _blockNumber);
  event MockNow(uint256 _mockedNow);

  uint blockNumber = 0;

  uint mockedNow = 0;

  function ArbitrationMock(address _jurToken, address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash)
    Arbitration(_jurToken, _parties, _dispersal, _funding, _agreementHash)
  {

  }

  function getBlockNumber() internal constant returns (uint) {
      return blockNumber;
  }

  function setMockedBlockNumber(uint256 _blockNumber) public {
      blockNumber = _blockNumber;
      MockBlockNumber(blockNumber);
  }

  function getNow() internal constant returns (uint256) {
      return mockedNow;
  }

  function setMockedNow(uint256 _mockedNow) public {
      mockedNow = _mockedNow;
      MockNow(mockedNow);
  }

}
