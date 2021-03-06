const assertFail = require("./helpers/assertFail");

const ArbitrationFactory = artifacts.require("./ArbitrationFactoryMock.sol");
const Arbitration = artifacts.require("./ArbitrationMock.sol");
const JURToken = artifacts.require("./JURToken.sol");

contract('Arbitration - no dispute', function (accounts) {

  var token;
  var arbitrationFactory;
  var arbitration;
  var party1 = accounts[1];
  var party2 = accounts[2];
  var voter1 = accounts[3];

  // =========================================================================
  it("0. initialize token contract and arbitration factory contract", async () => {

    token = await JURToken.new(["sig1"], {from: accounts[0]});
    console.log("JUR Token Address: ", token.address);

    //Mint some tokens for party1 and party2
    await token.mint(party1, 50, {from: accounts[0]});
    await token.mint(party2, 100, {from: accounts[0]});
    await token.mint(voter1, 100, {from: accounts[0]});

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
  });

  it("3. only parties can sign arbitration", async () => {
    await assertFail(async () => {
      await arbitration.sign({from: voter1});
    });
  });

  it("4. party1 signs arbitration", async () => {
    await arbitration.sign({from: party1});
  });

  it("5. party1 unsigns arbitration", async () => {
    await arbitration.unsign({from: party1});
  });

  it("6. party1 resigns arbitration", async () => {
    await token.approve(arbitration.address, 50, {from: party1});
    await arbitration.sign({from: party1});
  });

  it("7. party2 signs arbitration - state is now Signed", async () => {
    await arbitration.sign({from: party2});
    let state = await arbitration.state();
    assert.equal(state, 1);
  });

  it("8. only parties can agree arbitration", async () => {
    await assertFail(async () => {
      await arbitration.agree({from: voter1});
    });
  });

  it("9. party2 agrees arbitration", async () => {
    await arbitration.agree({from: party2});
    let state = await arbitration.state();
    assert.equal(state, 1);
  });

  it("10. party1 agrees arbitration - state is now Agreed", async () => {
    await arbitration.agree({from: party1});
    let state = await arbitration.state();
    assert.equal(state, 2);
  });

  it("11. only parties can withdraw dispersals", async () => {
    await assertFail(async () => {
      await arbitration.withdrawDispersal({from: voter1});
    });
  });

  it("12. party1 withdraws dispersal (zero tokens)", async () => {
    let initialBalance = await token.balanceOf(party1);
    await arbitration.withdrawDispersal({from: party1});
    let finalBalance = await token.balanceOf(party1);
    //Party 1 dispersal is 0
    assert.isTrue(finalBalance.sub(initialBalance).toNumber() == 0);
  });

  it("13. party2 withdraws dispersal (150 tokens) - state is now Closed", async () => {
    let initialBalance = await token.balanceOf(party2);
    await arbitration.withdrawDispersal({from: party2});
    let finalBalance = await token.balanceOf(party2);
    //Party 1 dispersal is 0
    assert.isTrue(finalBalance.sub(initialBalance).toNumber() == 150);
    let state = await arbitration.state();
    assert.equal(state, 4);
  });

});
