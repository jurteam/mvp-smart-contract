const assertFail = require("./helpers/assertFail");

const ArbitrationFactory = artifacts.require("./ArbitrationFactoryMock.sol");
const Arbitration = artifacts.require("./ArbitrationMock.sol");
const JURToken = artifacts.require("./JURToken.sol");

contract('Arbitration - Tied dispute', function (accounts) {

  var token;
  var arbitrationFactory;
  var arbitration;
  var party1 = accounts[1];
  var party2 = accounts[2];
  var voter1 = accounts[3];
  var voter2 = accounts[4];
  var voter3 = accounts[5];
  var voter4 = accounts[6];

  // =========================================================================
  it("0. initialize token contract and arbitration factory contract", async () => {

    token = await JURToken.new(["sig1"], {from: accounts[0]});
    console.log("JUR Token Address: ", token.address);

    //Mint some tokens for party1 and party2
    await token.mint(party1, 50, {from: accounts[0]});
    await token.mint(party2, 100, {from: accounts[0]});
    await token.mint(voter1, 100, {from: accounts[0]});
    await token.mint(voter2, 100, {from: accounts[0]});
    await token.mint(voter3, 100, {from: accounts[0]});
    await token.mint(voter4, 100, {from: accounts[0]});

    //Initialise arbitration contract
    arbitrationFactory = await ArbitrationFactory.new(token.address, {from: accounts[0]});
    console.log("Arbitration Factory Address: ", arbitrationFactory.address);

  });

  it("1. create new arbitration - state is unsigned", async () => {
    let tx = await arbitrationFactory.createArbitration([party1, party2], [0, 150], [50, 100], "Do some work...");
    arbitration = Arbitration.at(tx.logs[0].args._arbitration);
    console.log("Arbitration Address: " + arbitration.address);
    let party1Dispersal = await arbitration.dispersal(party1);
    let party2Dispersal = await arbitration.dispersal(party2);
    let party1Funding = await arbitration.funding(party1);
    let party2Funding = await arbitration.funding(party2);
    assert.equal(party1Dispersal.toNumber(), 0);
    assert.equal(party2Dispersal.toNumber(), 150);
    assert.equal(party1Funding.toNumber(), 50);
    assert.equal(party2Funding.toNumber(), 100);
    let state = await arbitration.state();
    assert.equal(state, 0);
  });

  it("2. approve arbitration for transfers", async () => {
    await token.approve(arbitration.address, 50, {from: party1});
    await token.approve(arbitration.address, 100, {from: party2});
    await token.approve(arbitration.address, 100, {from: voter1});
    await token.approve(arbitration.address, 100, {from: voter2});
    await token.approve(arbitration.address, 100, {from: voter3});
    await token.approve(arbitration.address, 100, {from: voter4});
  });

  it("3. only parties can sign arbitration", async () => {
    await assertFail(async () => {
      await arbitration.sign({from: voter1});
    });
  });

  it("4. party1 signs arbitration", async () => {
    await arbitration.sign({from: party1});
  });

  it("5. party2 signs arbitration - state is now Signed", async () => {
    await arbitration.sign({from: party2});
    let state = await arbitration.state();
    assert.equal(state, 1);
  });

  it("6. party1 disputes arbitration with sufficient vote", async () => {
    await token.mint(party1, 10, {from: accounts[0]});
    await token.approve(arbitration.address, 10, {from: party1});
    await arbitration.dispute(10, [50, 100], {from: party1});
    let state = await arbitration.state();
    assert.equal(state, 3);
    assert.equal((await arbitration.disputeDispersal(party1, party1)).toNumber(), 50);
    assert.equal((await arbitration.disputeDispersal(party1, party2)).toNumber(), 100);
    assert.equal((await arbitration.disputeDispersal(party2, party1)).toNumber(), 0);
    assert.equal((await arbitration.disputeDispersal(party2, party2)).toNumber(), 150);
  });

  it("7. party2 sets their dispute dispersal", async () => {
    await arbitration.amendDisputeDispersal([25, 125], {from: party2});
    let state = await arbitration.state();
    assert.equal(state, 3);
    assert.equal((await arbitration.disputeDispersal(party1, party1)).toNumber(), 50);
    assert.equal((await arbitration.disputeDispersal(party1, party2)).toNumber(), 100);
    assert.equal((await arbitration.disputeDispersal(party2, party1)).toNumber(), 25);
    assert.equal((await arbitration.disputeDispersal(party2, party2)).toNumber(), 125);
  });

  it("8. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION", async () => {
    await arbitration.setMockedNow(1 * 24 * 60 * 60);
    await assertFail(async () => {
      await arbitration.amendDisputeDispersal([25, 125], {from: party2});
    });
  });

  it("9. start voting", async () => {
    await arbitration.vote(party2, 10, {from: voter1});
    await arbitration.vote(party1, 10, {from: voter2});
    await arbitration.vote(party2, 20, {from: voter3});
    //Party1 has 20 votes, Party2 has 30 votes
    assert.equal((await arbitration.totalVotes()).toNumber(), 50);
    assert.equal((await arbitration.partyVotes(party1)).toNumber(), 20);
    assert.equal((await arbitration.partyVotes(party2)).toNumber(), 30);
  });

  it("10. vote is extended due to lots of votes during last 30 minutes", async () => {
    await arbitration.setMockedNow((8 * 24 * 60 * 60) - 1);
    await arbitration.vote(party2, 10, {from: voter3});
    await arbitration.setMockedNow(8 * 24 * 60 * 60);
    let endTime = await arbitration.calcDisputeEnds.call();
    assert.equal(endTime.toNumber(), (8 * 24 * 60 * 60) + (30 * 60));
    await arbitration.setMockedNow((8 * 24 * 60 * 60) + (5 * 60));
    //Party1 has 20 votes, Party2 has 40 votes
    assert.equal((await arbitration.totalVotes()).toNumber(), 60);
    assert.equal((await arbitration.partyVotes(party1)).toNumber(), 20);
    assert.equal((await arbitration.partyVotes(party2)).toNumber(), 40);
  });

  it("11. unable to payout voters due to extended window", async () => {
    await assertFail(async () => {
      await arbitration.payoutVoter(0, 10, {from: voter1});
    });
  });

  it("12. able to vote during extended window", async () => {
    await arbitration.vote(party1, 1, {from: voter3});
    //Party1 has 21 votes, Party2 has 40 votes
    assert.equal((await arbitration.totalVotes()).toNumber(), 61);
    assert.equal((await arbitration.partyVotes(party1)).toNumber(), 21);
    assert.equal((await arbitration.partyVotes(party2)).toNumber(), 40);
  });

  it("13. voters receive rewards", async () => {
    await arbitration.setMockedNow((9 * 24 * 60 * 60) + (30 * 60));
    let voter1Balance = await token.balanceOf(voter1);
    let voter2Balance = await token.balanceOf(voter2);
    let voter3Balance = await token.balanceOf(voter3);
    await arbitration.payoutVoter(0, 10, {from: voter1});
    await arbitration.payoutVoter(0, 10, {from: voter2});
    await arbitration.payoutVoter(0, 10, {from: voter3});
    let voter1FinalBalance = await token.balanceOf(voter1);
    let voter2FinalBalance = await token.balanceOf(voter2);
    let voter3FinalBalance = await token.balanceOf(voter3);
    //Voter1 gets 10 reward tokens, and their original 10 tokens
    //Voter2 loses their staked tokens
    //Voter3 gets 11 reward tokens and 30 of their original 31 staked tokens
    assert.equal(voter1FinalBalance.sub(voter1Balance).toNumber(), 20);
    assert.equal(voter2FinalBalance.sub(voter2Balance).toNumber(), 0);
    assert.equal(voter3FinalBalance.sub(voter3Balance).toNumber(), 41);
  });

  it("14. parties receive payouts", async () => {
    let party1Balance = await token.balanceOf(party1);
    let party2Balance = await token.balanceOf(party2);
    await arbitration.payoutParty({from: party1});
    await arbitration.payoutParty({from: party2});
    await arbitration.payoutVoter(0, 10, {from: party1});
    await arbitration.payoutVoter(0, 10, {from: party2});
    let party1FinalBalance = await token.balanceOf(party1);
    let party2FinalBalance = await token.balanceOf(party2);
    //Party1 gets 50 dispersal tokens, 10 reward tokens and their 10 voting tokens
    //Party2 gets 100 dispersal tokens, and no reward tokens
    assert.equal(party1FinalBalance.sub(party1Balance).toNumber(), 25);
    assert.equal(party2FinalBalance.sub(party2Balance).toNumber(), 125);
  });

});
