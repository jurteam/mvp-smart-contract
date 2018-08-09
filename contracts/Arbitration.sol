pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/math/Math.sol";

contract Arbitration {
  using SafeMath for uint256;

  event StateChange(State _oldState, State _newState, uint256 _timestamp);
  event ContractCreated(address indexed _party1, address indexed _party2, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);
  event ContractSigned(address indexed _party, uint256 _funding);
  event ContractUnsigned(address indexed _party, uint256 _funding);
  event ContractAgreed(address indexed _party);
  event ContractUnagreed(address indexed _party);
  event ContractAmendmentProposed(address indexed _party, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);
  event ContractAmendmentAgreed(address indexed _party);
  event ContractAmendmentUnagreed(address indexed _party);
  event ContractWithdrawn(address indexed _party, uint256 _dispersal);
  event ContractDisputed(address indexed _party, uint256[] _dispersal);
  event ContractDisputeDispersalAmended(address indexed _party, uint256[] _dispersal);

  event DisputeEndsAdjusted(uint256 _oldDisputeEnds, uint256 _newDisputeEnds);

  event VoteCast(address indexed _voter, address indexed _party, uint256 _amount);
  event VoterPayout(address indexed _voter, uint256 _stakedAmount, uint256 _rewardAmount);
  event PartyPayout(address indexed _party, uint256 _dispersalAmount);

  //Token for escrow & voting
  ERC20 public jurToken;

  //Globals - could be pulled from factory contract or passed in to constructor
  uint256 public DISPUTE_VOTE_DURATION = 7 days;
  uint256 public DISPUTE_DISPERSAL_DURATION = 1 days;
  uint256 public DISPUTE_WINDOW = 30 minutes;
  uint256 public DISPUTE_EXTENSION = 30 minutes;
  uint256 public VOTE_LOCKUP = 24 hours; //amount of time users must wait to withdraw their tokens
  uint256 public DISPUTE_WINDOW_MAX = 5 * 10**16; //percentage multiplued by 10**16
  uint256 public MIN_VOTE = 1 * 10**16; //percentage multiplied by 10**16
  uint256 public MIN_WIN = 1 * 10**16; //percentage multiplied by 10**16

  //Agreement Details
  address[] public allParties;
  mapping (address => bool) public parties;
  mapping (address => uint256) public dispersal;
  mapping (address => uint256) public funding;
  mapping (address => uint256) public amendedDispersal;
  mapping (address => uint256) public amendedFunding;
  mapping (address => mapping (address => uint256)) public disputeDispersal;
  bytes32 public agreementHash;
  bytes32 public amendedAgreementHash;

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
  enum State {Unsigned, Signed, Agreed, Dispute, Closed}
  State public state = State.Unsigned;

  //Decimals used for voting token
  uint256 constant DECIMALS = 10 ** 18;

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

  /**
   * @dev Constructor
   * @param _jurToken Address of the JUR token
   * @param _parties Addresses of parties involved in arbitration
   * @param _dispersal Dispersal of funds if arbitration agreed
   * @param _funding Source of funds for arbitration
   * @param _agreementHash Hash of arbitration agreement
   */
  constructor(address _jurToken, address[] _parties, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {

    //Check that we are only setting up an arbitration between two parties
    require((_dispersal.length == 2) && (_funding.length == 2) && (_parties.length == 2));

    //Check that party addresses are valid
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

    emit ContractCreated(_parties[0], _parties[1], _dispersal, _funding, _agreementHash);
  }

  function setState(State _state) internal {
    emit StateChange(state, _state, getNow());
    state = _state;
  }

  //Functions to sign and unsign contract

  /**
   * @dev Allows sender to sign agreeement
   */
  function sign() public {
    _sign(msg.sender);
  }

  /**
   * @dev Allows sender to sign agreeement using approve and call
   * @param _sender Address of signing party
   */
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
    emit ContractSigned(_sender, funding[_sender]);
  }

  /**
   * @dev Allows sender to unsign agreeement
   */
  function unsign() public hasState(State.Unsigned) onlyParties {
    require(hasSigned[msg.sender]);
    hasSigned[msg.sender] = false;
    require(jurToken.transfer(msg.sender, funding[msg.sender]));
    emit ContractUnsigned(msg.sender, funding[msg.sender]);
  }

  //Functions to agree / unagree contract

  /**
   * @dev Allows sender to agree dispersals (so that funds can be dispursed)
   */
  function agree() public hasState(State.Signed) onlyParties {
    require(!hasAgreed[msg.sender]);
    hasAgreed[msg.sender] = true;
    // If there is an amendment proposed, but not agreed refund all amendment funds
    if (amendmentProposed) {
      unagreeAmendment();
    }
    bool allAgreed = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allAgreed = allAgreed && hasAgreed[allParties[i]];
    }
    if (allAgreed) {
      setState(State.Agreed);
    }
    emit ContractAgreed(msg.sender);
  }

  /**
   * @dev Allows sender to unagree dispersals (so that funds cannot be dispursed)
   */
  function unagree() public hasState(State.Signed) onlyParties {
    require(hasAgreed[msg.sender]);
    hasAgreed[msg.sender] = false;
    emit ContractUnagreed(msg.sender);
  }

  //Functions to propose a new dispersals / funding

  /**
   * @dev Allows sender to propose a new dispersal and agreement hash
   * @param _dispersal Dispersal of funds if arbitration agreed
   * @param _funding Source of funds for arbitration
   * @param _agreementHash Hash of arbitration agreement
   */
  function proposeAmendment(uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public {
    _proposeAmendment(msg.sender, _dispersal, _funding, _agreementHash);
  }

  /**
   * @dev Allows sender to propose a new dispersal and agreement hash using approve and call
   * @param _sender Address of amending party
   * @param _dispersal Dispersal of funds if arbitration agreed
   * @param _funding Source of funds for arbitration
   * @param _agreementHash Hash of arbitration agreement
   */
  function proposeAmendmentJUR(address _sender, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) public onlyJUR {
    _proposeAmendment(_sender, _dispersal, _funding, _agreementHash);
  }

  function _proposeAmendment(address _sender, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash) internal hasState(State.Signed) isParty(_sender) {
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
    amendedAgreementHash = _agreementHash;
    //Must pay any excess dispersal required
    _agreeAmendment(_sender);
    emit ContractAmendmentProposed(_sender, _dispersal, _funding, _agreementHash);
  }

  //Functions to agree or unagree a new amendment

  /**
   * @dev Allows sender to agree an amendment to dispersals and agreement hash
   */
  function agreeAmendment() public {
    _agreeAmendment(msg.sender);
  }

  /**
   * @dev Allows sender to agree an amendment to dispersals and agreement hash using approve and call
   * @param _sender Address of amendment agreeing party
   */
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
    emit ContractAmendmentAgreed(_sender);
    bool allFundedAmendment = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allFundedAmendment = allFundedAmendment && hasFundedAmendment[allParties[i]];
    }
    // If all parties have funded / agreed an amendment, refund any excess and reset proposals
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
      agreementHash = amendedAgreementHash;
    }

  }

  /**
   * @dev Allows sender to unagree an amendment to dispersals and agreement hash
   */
  function unagreeAmendment() public hasState(State.Signed) onlyParties {
    //Could be done by original proposer, or other party
    //If anyone disagrees, amendment is removed
    require(amendmentProposed);
    amendmentProposed = false;
    //Refund any deficits paid
    for (uint8 i = 0; i < allParties.length; i++) {
      if (hasFundedAmendment[allParties[i]]) {
        hasFundedAmendment[allParties[i]] = false;
        if (amendedFunding[allParties[i]] > funding[allParties[i]]) {
          uint256 excess = amendedFunding[allParties[i]].sub(funding[allParties[i]]);
          require(jurToken.transfer(allParties[i], excess));
        }
      }
    }
    emit ContractAmendmentUnagreed(msg.sender);
  }

  /**
   * @dev Once a contract has been agreed withdrawals dispersal amount
   */
  function withdrawDispersal() public hasState(State.Agreed) onlyParties {
    require(!hasWithdrawn[msg.sender]);
    hasWithdrawn[msg.sender] = true;
    require(jurToken.transfer(msg.sender, dispersal[msg.sender]));
    bool allWithdrawn = true;
    for (uint8 i = 0; i < allParties.length; i++) {
      allWithdrawn = allWithdrawn && (hasWithdrawn[allParties[i]] || (dispersal[allParties[i]] == 0));
    }
    emit ContractWithdrawn(msg.sender, dispersal[msg.sender]);
    if (allWithdrawn) {
      setState(State.Closed);
    }
  }

  //Functions to initiate a dispute

  /**
   * @dev Allows sender to put the arbitration into a dispute State
   * @param _voteAmount Amount of tokens to stake to the disputing parties side
   * @param _dispersal Dispersal should the disputing party win
   */
  function dispute(uint256 _voteAmount, uint256[] _dispersal) public {
    _dispute(msg.sender, _voteAmount, _dispersal);
  }

  /**
   * @dev Allows sender to put the arbitration into a dispute State using approve and call
   * @param _sender Address of disputing party
   * @param _voteAmount Amount of tokens to stake to the disputing parties side
   * @param _dispersal Dispersal should the disputing party win
   */
  function disputeJUR(address _sender, uint256 _voteAmount, uint256[] _dispersal) public onlyJUR {
    _dispute(_sender, _voteAmount, _dispersal);
  }

  function _dispute(address _sender, uint256 _voteAmount, uint256[] _dispersal) internal hasState(State.Signed) isParty(_sender) {
    require(_dispersal.length == allParties.length);
    // If there is an amendment proposed, but not agreed refund all amendment funds
    if (amendmentProposed) {
      unagreeAmendment();
    }
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
    //Default other parties dispute dispersals
    for (uint8 j = 0; j < allParties.length; j++) {
      if (allParties[j] != _sender) {
        disputeDispersal[allParties[j]][allParties[j]] = totalFunding;
      }
    }
    //Default reject option dispute dispersals
    for (uint8 k = 0; k < allParties.length; k++) {
      disputeDispersal[address(0)][allParties[k]] = funding[allParties[k]];
    }
    emit ContractDisputed(_sender, _dispersal);
    _vote(_sender, _sender, _voteAmount);
  }

  /**
   * @dev Allows sender to amend their dispersals should they win
   * @param _dispersal Dispersal should the disputing party win
   */
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
    emit ContractDisputeDispersalAmended(msg.sender, _dispersal);
  }

  /**
   * @dev Calculates the current end time of the voting period
   */
  function calcDisputeEnds() public hasState(State.Dispute) returns(uint256) {
    //Extend dispute period if:
    //  - vote is tied
    //  - more than 5% of votes places in last 30 minutes of dispute period
    if (getNow() < disputeEnds) {
      return disputeEnds;
    }
    if (disputeWindowVotes > totalVotes.mul(DISPUTE_WINDOW_MAX).div(10**18)) {
      disputeWindowVotes = 0;
      return disputeEnds.add(DISPUTE_EXTENSION);
    }
    uint256 winningVotes = partyVotes[address(0)];
    for (uint8 i = 0; i < allParties.length; i++) {
      if (partyVotes[allParties[i]] > winningVotes) {
        winningVotes = partyVotes[allParties[i]];
      }
    }
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
      disputeWindowVotes = 0;
      //New end time is calculated from now
      return getNow().add(DISPUTE_EXTENSION);
    }
    return disputeEnds;
  }

  //Functions to allow voting on disputed agreements

  /**
   * @dev Allows sender to vote
   * @param _voteAddress Address of party who is being voted for (0 for reject option)
   * @param _voteAmount Amount of tokens to stake to the _voteAddress side
   */
  function vote(address _voteAddress, uint256 _voteAmount) public {
    _vote(msg.sender, _voteAddress, _voteAmount);
  }

  /**
   * @dev Allows sender to vote using approve and call
   * @param _sender Address of voting party
   * @param _voteAddress Address of party who is being voted for (0 for reject option)
   * @param _voteAmount Amount of tokens to stake to the _voteAddress side
   */
  function voteJUR(address _sender, address _voteAddress, uint256 _voteAmount) public onlyJUR {
    _vote(_sender, _voteAddress, _voteAmount);
  }

  function _vote(address _sender, address _voteAddress, uint256 _voteAmount) internal hasState(State.Dispute) {
    uint256 newDisputeEnds = calcDisputeEnds();
    if (newDisputeEnds != disputeEnds) {
      emit DisputeEndsAdjusted(newDisputeEnds, disputeEnds);
      disputeEnds = newDisputeEnds;
    }
    require(getNow() < disputeEnds);
    //Parties are allowed to vote straightaway
    require((getNow() >= disputeStarts) || parties[_sender]);
    //Check vote is for a valid address
    require(parties[_voteAddress] || (_voteAddress == address(0)));
    //Vote must be at least MIN_VOTE of the totalVotes
    require(_voteAmount >= totalVotes.mul(MIN_VOTE).div(10**18));
    //Vote must not mean the new winning party after the vote has strictly more than twice the next best party
    if (totalVotes != 0) {
      address winnerParty;
      address bestMinortyParty;
      (winnerParty, bestMinortyParty) = getWinnerAndBestMinorty();
      if (_voteAddress == winnerParty) {
        require(partyVotes[_voteAddress].add(_voteAmount) <=  partyVotes[bestMinortyParty].mul(2));
      } else {
        require(partyVotes[_voteAddress].add(_voteAmount) <=  partyVotes[winnerParty].mul(2));
      }
    }

    Vote memory newVote = Vote(_voteAmount, partyVotes[_voteAddress], false);

    //Commit votes
    require(jurToken.transferFrom(_sender, address(this), _voteAmount));

    //Track votes during last 30 mins of voting period
    if (getNow() >= disputeEnds.sub(30 * 60)) {
      disputeWindowVotes = disputeWindowVotes.add(_voteAmount);
    }

    //Record votes
    totalVotes = totalVotes.add(_voteAmount);
    partyVotes[_voteAddress] = partyVotes[_voteAddress].add(_voteAmount);
    userVotes[_sender][_voteAddress].push(newVote);

    emit VoteCast(_sender, _voteAddress, _voteAmount);

  }

  /**
   * @dev Allows sender (voter) to claim their staked and reward tokens
   * @param _start Index at which to start iterating through votes
   * @param _end Index at which to end iterating through votes
   */
  function payoutVoter(uint256 _start, uint256 _end) public hasState(State.Dispute) {
    //Generally setting _start to 0 and _end to a large number should be fine, but having the option avoids a possible block gas limit issue
    uint256 newDisputeEnds = calcDisputeEnds();
    if (newDisputeEnds != disputeEnds) {
      emit DisputeEndsAdjusted(newDisputeEnds, disputeEnds);
      disputeEnds = newDisputeEnds;
    }
    require(getNow() >= disputeEnds.add(VOTE_LOCKUP));
    //There should be a clear winner now, otherwise the dispute would have been extended.
    address winnerParty;
    address bestMinortyParty;
    (winnerParty, bestMinortyParty) = getWinnerAndBestMinorty();
    uint256 totalMinorityVotes = totalVotes.sub(partyVotes[winnerParty]);
    uint256 bestMinorityVotes = partyVotes[bestMinortyParty];

    //If there were no votes on any minority options (all votes on the winner) then there is no payout
    uint256 reward = 0;
    if (totalMinorityVotes != 0) {
      reward = decimalDiv(totalMinorityVotes, bestMinorityVotes);
    }

    uint256 eligableVotes = 0;
    uint256 stakedVotes = 0;

    for (uint256 i = _start; i < Math.min256(userVotes[msg.sender][winnerParty].length, _end); i++) {
      if (!userVotes[msg.sender][winnerParty][i].claimed) {
        userVotes[msg.sender][winnerParty][i].claimed = true;
        stakedVotes = stakedVotes.add(userVotes[msg.sender][winnerParty][i].amount);
        if (userVotes[msg.sender][winnerParty][i].previousVotes < bestMinorityVotes) {
          eligableVotes = eligableVotes.add(Math.min256(bestMinorityVotes.sub(userVotes[msg.sender][winnerParty][i].previousVotes), userVotes[msg.sender][winnerParty][i].amount));
        }
      }
    }
    require(jurToken.transfer(msg.sender, stakedVotes.add(decimalMul(eligableVotes, reward))));
    emit VoterPayout(msg.sender, stakedVotes, decimalMul(eligableVotes, reward));
  }

  /**
   * @notice Returns the current winner
   */
  function getWinner() public view returns(address) {
    uint256 winnerVotes = partyVotes[address(0)];
    address winnerParty = address(0);
    for (uint8 i = 0; i < allParties.length; i++) {
      if (winnerVotes < partyVotes[allParties[i]]) {
        winnerVotes = partyVotes[allParties[i]];
        winnerParty = allParties[i];
      }
    }
    return winnerParty;
  }

  /**
   * @notice Returns the current winner and next best minority party
   */
  function getWinnerAndBestMinorty() public view returns(address, address) {
    address winnerParty = getWinner();
    address bestMinorityParty = (winnerParty == address(0)) ? allParties[0] : address(0);
    uint256 bestMinorityVotes = partyVotes[bestMinorityParty];
    for (uint8 j = 0; j < allParties.length; j++) {
      if ((bestMinorityVotes < partyVotes[allParties[j]]) && (winnerParty != allParties[j])) {
        bestMinorityParty = allParties[j];
        bestMinorityVotes = partyVotes[bestMinorityParty];
      }
    }
    return (winnerParty, bestMinorityParty);
  }

  /**
   * @dev Allows sender (party) to claim their dispersal tokens
   */
  function payoutParty() public hasState(State.Dispute) onlyParties {
    uint256 newDisputeEnds = calcDisputeEnds();
    if (newDisputeEnds != disputeEnds) {
      emit DisputeEndsAdjusted(newDisputeEnds, disputeEnds);
      disputeEnds = newDisputeEnds;
    }
    require(getNow() >= disputeEnds);
    require(!hasWithdrawn[msg.sender]);
    hasWithdrawn[msg.sender] = true;
    address winnerParty = getWinner();
    uint256 payout = disputeDispersal[winnerParty][msg.sender];
    require(jurToken.transfer(msg.sender, payout));
    emit PartyPayout(msg.sender, payout);
  }

  /**
   * @notice Returns division assuming both inputs are decimals multiplied by DECIMALS
   */
  function decimalDiv(uint256 x, uint256 y) internal pure returns (uint256) {
    return x.mul(DECIMALS).div(y);
  }

  /**
   * @notice Returns multiplication assuming both inputs are decimals multiplied by DECIMALS
   */
  function decimalMul(uint256 x, uint256 y) internal pure returns (uint256) {
    return x.mul(y).div(DECIMALS);
  }

  /**
   * @notice Returns current timestamp
   */
  function getNow() internal constant returns (uint256) {
    return now;
  }

}
