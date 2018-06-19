pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Arbitration.sol";

contract ArbitrationFactory is Ownable {

  event ArbitrationCreated(address indexed _creator, address _arbitration, address indexed _party1, address indexed _party2, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);

  address public jurToken;
  address[] public arbirations;

  /**
   * @dev Constructor
   * @param _jurToken Address of the JUR token
   */
  constructor(address _jurToken) public {
    jurToken = _jurToken;
  }

  /**
   * @dev Creates a new arbitration
   * @param _parties Addresses of parties involved in arbitration
   * @param _dispersal Dispersal of funds if arbitration agreed
   * @param _funding Source of funds for arbitration
   * @param _agreementHash Hash of arbitration agreement
   */
  function createArbitration(address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {
    address newArbitration = new Arbitration(jurToken, _parties, _dispersal, _funding, _agreementHash);
    arbirations.push(newArbitration);
    emit ArbitrationCreated(msg.sender, newArbitration, _parties[0], _parties[1], _dispersal, _funding, _agreementHash);
  }

  /**
   * @dev Changes the address of the JUR token
   * @param _jurToken New address of the JUR token
   */
  function changeToken(address _jurToken) onlyOwner public {
    jurToken = _jurToken;
  }

  /**
   * @notice Returns the hash of an agreement string
   */
  function generateHash(string _input) pure public returns (bytes32) {
    return keccak256(bytes(_input));
  }

}
