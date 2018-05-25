pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';

contract Arbitration {
  using SafeMath for uint256;

  event StateChange(State _oldState, State _newState);
  event VoteCast(address _voter, address _party, uint256 _amount);
  event ContractSigned(address _party, uint256 _amount);
  event ContractUnsigned(address _party, uint256 _amount);
  event ContractCreated(address _party1, address _party2, uint256 _party1Dispersal, uint256 _party2Dispersal, uint256 _party1Funding, uint256 _party2Funding, address _paymentTokem, bytes32 _agreementHash);
  event VoterPayout(address _voter, uint256 _tokenAmount);
  event PartyPayout(address _party, uint256 _tokenAmount);

  //Token for escrow & voting
  ERC20 public jurToken;

  //Globals - could be pulled from factory contract
  uint256 public DISPUTE_VOTE_DURATION = 7 days;
  uint256 public DISPUTE_DISPERSAL_DURATION = 1 days;
  uint256 public DISPUTE_WINDOW = 30 minutes;
  uint256 public DISPUTE_EXTENSION = 30 minutes;
  uint256 public DISPUTE_WINDOW_MAX = 5 * 10**16; //percentage multiplued by 10**16
  uint256 public MIN_VOTE = 1 * 10**16; //percentage multiplued by 10**16

  //Agreement Details
  address[] public allParties;
  mapping (address => bool) public parties;
  mapping (address => uint256) public dispersal;
  mapping (address => uint256) public funding;
  mapping (address => uint256) public amendedDispersal;
  mapping (address => uint256) public amendedFunding;
  mapping (address => mapping (address => uint256)) public disputeDispersal;
  bytes32 public agreementHash;

  //User granularity state tracking
  mapping (address => bool) public hasSigned;
  mapping (address => bool) public hasAgreed;
  mapping (address => bool) public hasWithdrawn;
  mapping (address => bool) public hasFundedAmendment;
  bool public amendmentProposed;

  //Dispute / voting parameters
  uint256 public disputeStarts;
  uint256 public disputeEnds;
  uint256 public totalVotes;
  uint256 public disputeWindowVotes;
  mapping (address => uint256) public partyVotes;
  mapping (address => mapping (address => Vote[])) userVotes;

  struct Vote {
    uint256 amount;
    uint256 previousVotes;
    bool claimed;
  }

  //Initialise state
  enum State {Unsigned, Signed, Agreed, Dispute, Closed, DisputeClosed}
  State public state = State.Unsigned;

  modifier onlyParties {
    require(parties[msg.sender]);
    _;
  }

  modifier isParty(address _sender) {
    require(parties[_sender]);
    _;
  }

  modifier hasState(State _state) {
    require(state == _state);
    _;
  }

  modifier onlyJUR {
    require(msg.sender == address(jurToken));
    _;
  }

  constructor(address _jurToken, address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {

    //Check that we are only setting up an arbitration between two parties
    require((_dispersal.length == 2) && (_funding.length == 2) && (_parties.length == 2));
    require((_parties[0] != 0x0) && (_parties[1] != 0x0));

    //Check that dispersals match funding and initialise mappings
    uint256 totalFunding = 0;
    uint256 totalDispersal = 0;
    for (uint8 i = 0; i < _parties.length; i++) {
      parties[_parties[i]] = true;
      dispersal[_parties[i]] = _dispersal[i];
      funding[_parties[i]] = _funding[i];
      totalDispersal = totalDispersal.add(_dispersal[i]);
      totalFunding = totalFunding.add(_funding[i]);
    }
    require(totalFunding == totalDispersal);
    allParties = _parties;
    agreementHash = _agreementHash;

    //Initialise JUR token
    jurToken = ERC20(_jurToken);

  }

  function setState(State _state) internal {
    StateChange(state, _state);
    state = _state;
  }

  function sign() public {
    _sign(msg.sender);
  }

  function signJUR(address _sender) public onlyJUR {
    _sign(_sender);
  }

  function _sign(address _sender) internal hasState(State.Unsigned) isParty(_sender) {
    require(!hasSigned[_sender]);
    hasSigned[_sender] = true;
    require(jurToken.transferFrom(_sender, address(this), funding[_sender]));
    bool allSigned = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allSigned = allSigned && hasSigned[allParties[i]];
    }
    if (allSigned) {
      setState(State.Signed);
    }
  }

  function unsign() public hasState(State.Unsigned) onlyParties {
    require(hasSigned[msg.sender]);
    hasSigned[msg.sender] = false;
    require(jurToken.transfer(msg.sender, funding[msg.sender]));
    //TODO - emit event
    /* ContractUnsigned(msg.sender, betAmount[msg.sender]); */
  }

  function agree() public hasState(State.Signed) onlyParties {
    require(!hasAgreed[msg.sender]);
    hasAgreed[msg.sender] = true;
    bool allAgreed = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allAgreed = allAgreed && hasAgreed[allParties[i]];
    }
    if (allAgreed) {
      setState(State.Agreed);
    }
    //TODO - emit event
  }

  function unagree() public hasState(State.Signed) onlyParties {
    require(hasAgreed[msg.sender]);
    hasAgreed[msg.sender] = false;
    //TODO - emit event
  }

  function proposeAmendment(uint256[] _dispersal, uint256[] _funding) public {
    _proposeAmendment(msg.sender, _dispersal, _funding);
  }

  function proposeAmendmentJUR(address _sender, uint256[] _dispersal, uint256[] _funding) public onlyJUR {
    _proposeAmendment(_sender, _dispersal, _funding);
  }

  function _proposeAmendment(address _sender, uint256[] _dispersal, uint256[] _funding) internal hasState(State.Signed) isParty(_sender) {
    //There can only be one proposed amendment at a time
    require(!amendmentProposed);
    amendmentProposed = true;
    require((_dispersal.length == allParties.length) && (_funding.length == allParties.length));
    uint256 totalFunding = 0;
    uint256 totalDispersal = 0;
    for (uint8 i = 0; i < allParties.length; i++) {
      amendedDispersal[allParties[i]] = _dispersal[i];
      amendedFunding[allParties[i]] = _funding[i];
      totalDispersal = totalDispersal.add(_dispersal[i]);
      totalFunding = totalFunding.add(_funding[i]);
    }
    require(totalFunding == totalDispersal);
    //Must pay any excess dispersal required
    _agreeAmendment(_sender);
  }

  function agreeAmendment() public {
    _agreeAmendment(msg.sender);
  }

  function agreeAmendmentJUR(address _sender) public onlyJUR {
    _agreeAmendment(_sender);
  }

  function _agreeAmendment(address _sender) internal hasState(State.Signed) isParty(_sender) {
    require(amendmentProposed);
    require(!hasFundedAmendment[_sender]);
    hasFundedAmendment[_sender] = true;
    if (amendedFunding[_sender] > funding[_sender]) {
      uint256 deficit = amendedFunding[_sender].sub(funding[_sender]);
      require(jurToken.transferFrom(_sender, address(this), deficit));
    }
    bool allFundedAmendment = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allFundedAmendment = allFundedAmendment && hasFundedAmendment[allParties[i]];
    }
    if (allFundedAmendment) {
      amendmentProposed = false;
      for (uint8 j = 0; j < allParties.length; j++) {
        hasFundedAmendment[allParties[j]] = false;
        if (amendedFunding[allParties[j]] < funding[allParties[j]]) {
          uint256 excess = funding[allParties[j]].sub(amendedFunding[allParties[j]]);
          require(jurToken.transfer(allParties[j], excess));
        }
        funding[allParties[j]] = amendedFunding[allParties[j]];
        dispersal[allParties[j]] = amendedDispersal[allParties[j]];
      }
    }
  }

  function unagreeAmendment() public onlyParties {
    //Could be done by original proposer, or other party
    //If anyone disagrees, amendment is removed
    require(amendmentProposed);
    amendmentProposed = false;
    //Refund any deficits paid
    for (uint8 i = 0; i < allParties.length; i++) {
      if (hasFundedAmendment[allParties[i]]) {
        hasFundedAmendment[allParties[i]] = false;
        if (amendedFunding[allParties[i]] > funding[allParties[i]]) {
          uint256 amount = amendedFunding[allParties[i]].sub(funding[allParties[i]]);
          require(jurToken.transfer(allParties[i], amount));
        }
      }
    }
  }

  function withdrawDispersal() public hasState(State.Agreed) onlyParties {
    require(!hasWithdrawn[msg.sender]);
    hasWithdrawn[msg.sender] = true;
    require(jurToken.transfer(msg.sender, dispersal[msg.sender]));
    bool allWithdrawn = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allWithdrawn = allWithdrawn && (hasWithdrawn[allParties[i]] || (dispersal[allParties[i]] == 0));
    }
    if (allWithdrawn) {
      setState(State.Closed);
    }
    //TODO - emit event
  }

  function dispute(uint256 _voteAmount, uint256[] _dispersal) public {
    _dispute(msg.sender, _voteAmount, _dispersal);
  }

  function disputeJUR(address _sender, uint256 _voteAmount, uint256[] _dispersal) public onlyJUR {
    _dispute(_sender, _voteAmount, _dispersal);
  }

  function _dispute(address _sender, uint256 _voteAmount, uint256[] _dispersal) internal hasState(State.Signed) isParty(_sender) {
    require(_dispersal.length == allParties.length);
    setState(State.Dispute);
    uint256 totalDispersal = 0;
    uint256 totalFunding = 0;
    for (uint8 i = 0; i < allParties.length; i++) {
      disputeDispersal[_sender][allParties[i]] = _dispersal[i];
      totalDispersal = totalDispersal.add(_dispersal[i]);
      totalFunding = totalFunding.add(funding[allParties[i]]);
    }
    require(totalDispersal == totalFunding);
    require(_voteAmount >= totalFunding.mul(MIN_VOTE).div(10**18));
    disputeStarts = SafeMath.add(getNow(), DISPUTE_DISPERSAL_DURATION);
    disputeEnds = SafeMath.add(disputeStarts, DISPUTE_VOTE_DURATION);
    totalVotes = _voteAmount;
    //Default other parties dispute dispersals
    for (uint8 j = 0; i < allParties.length; j++) {
      if (allParties[j] != _sender) {
        disputeDispersal[allParties[j]][allParties[j]] = totalFunding;
      }
    }
    //TODO - fix this
    _vote(_sender, _sender, _voteAmount);
  }

  function amendDisputeDispersal(uint256[] _dispersal) public hasState(State.Dispute) onlyParties {
    require(_dispersal.length == allParties.length);
    require(getNow() < disputeStarts);
    uint256 totalDispersal = 0;
    uint256 totalFunding = 0;
    for (uint8 i = 0; i < allParties.length; i++) {
      disputeDispersal[msg.sender][allParties[i]] = _dispersal[i];
      totalDispersal = totalDispersal.add(_dispersal[i]);
      totalFunding = totalFunding.add(funding[allParties[i]]);
    }
    require(totalDispersal == totalFunding);
  }

  function _endDisputeTime() internal hasState(State.Dispute) returns(uint256) {
    //Extend dispute period if:
    //  - vote is tied
    //  - more than 5% of votes places in last 30 minutes of dispute period
    if (getNow() < disputeEnds) {
      return disputeEnds;
    }
    uint256 winningVotes = partyVotes[address(0)];
    for (uint8 i = 0; i < allParties.length; i++) {
      if (partyVotes[allParties[i]] > winningVotes) {
        winningVotes = partyVotes[allParties[i]];
      }
    }
    if (disputeWindowVotes >= totalVotes.mul(DISPUTE_WINDOW_MAX).div(10**18)) {
      disputeEnds = getNow().add(DISPUTE_EXTENSION);
      disputeWindowVotes = 0;
      return disputeEnds;
    }
    //TODO: make more efficient
    uint8 countWinners = 0;
    if (partyVotes[address(0)] == winningVotes) {
      countWinners = countWinners + 1;
    }
    for (uint8 j = 0; j < allParties.length; j++) {
      if (partyVotes[allParties[j]] == winningVotes) {
        countWinners = countWinners + 1;
      }
    }
    if (countWinners > 1) {
      disputeEnds = getNow().add(DISPUTE_EXTENSION);
      disputeWindowVotes = 0;
      return disputeEnds;
    }
    return disputeEnds;
  }

  function vote(address _voteAddress, uint256 _voteAmount) public {
    _vote(msg.sender, _voteAddress, _voteAmount);
  }

  function voteJUR(address _sender, address _voteAddress, uint256 _voteAmount) public onlyJUR {
    _vote(_sender, _voteAddress, _voteAmount);
  }

  function _vote(address _sender, address _voteAddress, uint256 _voteAmount) internal hasState(State.Dispute) {

    require(getNow() < _endDisputeTime());
    //Parties are allowed to vote straightaway
    require((getNow() >= disputeStarts) || parties[_sender]);
    require(parties[_voteAddress] || (_voteAddress == address(0)));
    require(_voteAmount >= totalVotes.mul(MIN_VOTE).div(10**18));

    Vote memory newVote = Vote(_voteAmount, partyVotes[_voteAddress], false);

    //Commit votes
    require(jurToken.transferFrom(_sender, address(this), _voteAmount));

    //Track votes during last 30 mins of voting period
    if (getNow() >= _endDisputeTime().sub(30 * 60)) {
      disputeWindowVotes = disputeWindowVotes.add(_voteAmount);
    }

    //Record votes
    totalVotes = totalVotes.add(_voteAmount);
    partyVotes[_voteAddress] = partyVotes[_voteAddress].add(_voteAmount);
    userVotes[_sender][_voteAddress].push(newVote);

  }

  function payoutVoter(uint256 _start) public hasState(State.Dispute) {
    //TODO: Check vote has actually concluded
    //Generally setting _start to 0 should be fine, but having the option avoids a possible block gas limit issue
    require(getNow() >= disputeEnds);
    address winnerParty;
    address bestMinortyParty;
    (winnerParty, bestMinortyParty) = getWinnerAndBestMinorty();
    uint256 totalMinorityVotes = totalVotes.sub(partyVotes[winnerParty]);
    uint256 bestMinorityVotes = partyVotes[bestMinortyParty];
    uint256 reward = totalMinorityVotes.div(bestMinorityVotes);
    uint256 eligableVotes = 0;
    //TODO: does start really work here?
    for (uint256 i = _start; i < userVotes[msg.sender][winnerParty].length; i++) {
      if (!userVotes[msg.sender][winnerParty][i].claimed) {
        if (userVotes[msg.sender][winnerParty][i].previousVotes >= bestMinorityVotes) {
          //nothing left to pay out
          break;
        }
        eligableVotes = eligableVotes.add(Math.min256(bestMinorityVotes.sub(userVotes[msg.sender][winnerParty][i].previousVotes), userVotes[msg.sender][winnerParty][i].amount));
        userVotes[msg.sender][winnerParty][i].claimed = true;
      }
    }
    assert(jurToken.transfer(msg.sender, eligableVotes.mul(reward)));
    /* VoterPayout(msg.sender, payout); */
  }

  function getWinnerAndBestMinorty() public view returns(address, address) {
    uint256 winnerVotes = partyVotes[address(0)];
    address winnerParty = address(0);
    for (uint8 i = 0; i < allParties.length; i++) {
      if (winnerVotes < partyVotes[allParties[i]]) {
        winnerVotes = partyVotes[allParties[i]];
        winnerParty = allParties[i];
      }
    }
    uint256 bestMinortyVotes = (winnerParty == address(0)) ? partyVotes[allParties[0]] : partyVotes[address(0)];
    address bestMinortyParty = (winnerParty == address(0)) ? allParties[0] : address(0);
    for (uint8 j = 0; j < allParties.length; j++) {
      if ((bestMinortyVotes < partyVotes[allParties[j]]) && (winnerParty != allParties[j])) {
        bestMinortyVotes = partyVotes[allParties[j]];
        bestMinortyParty = allParties[j];
      }
    }
    return (winnerParty, bestMinortyParty);
  }
/*
  function getTotalMinorityVotes() public view returns(uint256) {
    uint256 maxVotes = partyVotes[address(0)];
    address maxParty = address(0);
    for (uint8 i = 0; i < allParties.length; i++) {
      if (maxVotes < partyVotes[allParties[i]]) {
        maxVotes = partyVotes[allParties[i]];
        maxParty = allParties[i];
      }
    }
    uint256 totalMinorityVotes = 0;
    if (maxParty != address(0)) {
      totalMinorityVotes = partyVotes[address(0)];
    }
    for (uint8 i = 0; i < allParties.length; i++) {
      if (allParties[i] != maxParty) {
        totalMinorityVotes = totalMinorityVotes.add(partyVotes[allParties[i]]);
      }
    }
    return totalMinorityVotes;
  }

  function getVotingOrder() public view returns(address[]) {
    //Make the assumption only three addresses here for simplicity
    address maxAddress = address(0);
    address minAddress = address(0);
    uint256 maxVotes = partyVotes[address(0)];
    uint256 minVotes = partyVotes[address(0)];
    for (uint8 i = 0; i < allParties.length; i++) {
      if (maxVotes < partyVotes[allParties[i]]) {
        maxVotes = partyVotes[allParties[i]];
        maxAddress = allParties[i]
      }
    }
  }

  function getBestMinorityVotes() public view returns(uint256) {
    uint256 maxVotes = partyVotes[address(0)];
    address maxParty = address(0);
    for (uint8 i = 0; i < allParties.length; i++) {
      if (maxVotes < partyVotes[allParties[i]]) {
        maxVotes = partyVotes[allParties[i]];
        maxParty = allParties[i];
      }
    }
    uint256 totalMinorityVotes = 0;
    if (maxParty != address(0)) {
      totalMinorityVotes = partyVotes[address(0)];
    }
    for (uint8 i = 0; i < allParties.length; i++) {
      if (allParties[i] != maxParty) {
        totalMinorityVotes = totalMinorityVotes.add(partyVotes[allParties[i]]);
      }
    }
    return totalMinorityVotes;
  } */

  function payoutParty() public hasState(State.Dispute) onlyParties {
    //TODO: check that vote has actually ended
    require(getNow() >= disputeEnds);
    require(!hasWithdrawn[msg.sender]);
    hasWithdrawn[msg.sender] = true;
    address winnerParty;
    address bestMinortyParty;
    (winnerParty, bestMinortyParty) = getWinnerAndBestMinorty();
    uint256 payout = disputeDispersal[winnerParty][msg.sender];
    //Now pay out original amount
    assert(jurToken.transfer(msg.sender, payout));
    PartyPayout(msg.sender, payout);
  }

  function getNow() internal constant returns (uint256) {
    return now;
  }

}
