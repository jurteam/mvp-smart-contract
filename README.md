# JUR Protocol

## Specification

See [JUR Protocol Specification](https://github.com/jurteam/mvp-smart-contract/blob/master/JUR%20Protocol%20Specification.md)

## Events

Events can be monitored via the web3 API to allow the dApp to react to changes within the smart contract(s).

Supported events are:
```
Arbitration.sol:  event StateChange(State _oldState, State _newState, uint256 _timestamp);
Arbitration.sol:  event ContractCreated(address indexed _party1, address indexed _party2, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);
Arbitration.sol:  event ContractSigned(address indexed _party, uint256 _funding);
Arbitration.sol:  event ContractUnsigned(address indexed _party, uint256 _funding);
Arbitration.sol:  event ContractAgreed(address indexed _party);
Arbitration.sol:  event ContractUnagreed(address indexed _party);
Arbitration.sol:  event ContractAmendmentProposed(address indexed _party, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);
Arbitration.sol:  event ContractAmendmentAgreed(address indexed _party);
Arbitration.sol:  event ContractAmendmentUnagreed(address indexed _party);
Arbitration.sol:  event ContractWithdrawn(address indexed _party, uint256 _dispersal);
Arbitration.sol:  event ContractDisputed(address indexed _party, uint256[] _dispersal);
Arbitration.sol:  event ContractDisputeDispersalAmended(address indexed _party, uint256[] _dispersal);
Arbitration.sol:  event DisputeEndsAdjusted(uint256 _oldDisputeEnds, uint256 _newDisputeEnds);
Arbitration.sol:  event VoteCast(address indexed _voter, address indexed _party, uint256 _amount);
Arbitration.sol:  event VoterPayout(address indexed _voter, uint256 _stakedAmount, uint256 _rewardAmount);
Arbitration.sol:  event PartyPayout(address indexed _party, uint256 _dispersalAmount);
ArbitrationFactory.sol:  event ArbitrationCreated(address indexed _creator, address _arbitration, address indexed _party1, address indexed _party2, uint256[] _dispersal, uint256[] _funding, bytes32 _agreementHash);
```

## Dependencies

1. This repo uses truffle, node and npm:  
https://nodejs.org/en/ (v8.4.0)  
http://truffle.readthedocs.io/en/beta/getting_started/installation/
https://github.com/trufflesuite/ganache-cli

1. Run `npm install` in the repo root directory.

## Compilation

To compile the contracts to bytecode, you can execute:  
`truffle compile`

This will display some warnings due to OpenZeppelin library files which can be ignored.

## Running Test Network

To run a test ethereum network, in a separate terminal execute:  
`ganache-cli --gasLimit 7000000`

## Deployment

The deployment is configured in `migrations/2_deploy_contracts.js`.

Settings in the migrations file and `truffle.js` should also be reviewed / modified before mainnet release.

To deploy, you can execute:  
`truffle migrate --reset`

which should output something similar to:
```
Using network 'development'.

Running migration: 2_deploy_contracts.js
  Deploying JURToken...
  ... 0xff2c945eb1e2ca59de9e7b18a516fd3d130dd1b837152d9f5e5d84dae32fca43
  JURToken: 0x2ef6dc25b5dd451221fca2f1d87048d6f0cb0cd3
  Deploying ArbitrationFactory...
  ... 0x12cbb2cf8864cce9c6b358722b823fd5f699aee3bce5371ffea194f9aae9f905
  ArbitrationFactory: 0x159247d9d7571bcb174c78e9d619b0dbbafd7b50
Saving successful migration to network...
  ... 0x155f86784aaa062932832859c04cf475605d732bbde235f7749472d28d0f8db5
Saving artifacts...
```

## Testing

Comprehensive test cases have been added for all contracts.

To test, you can execute:  
`truffle test`

which should output:
```
Using network 'development'.

  Contract: Arbitration - no dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0xe254a552ddf1d3cd5db6a1a69a8d7626402e4271
    ✓ 0. initialize token contract and arbitration factory contract (537ms)
Arbitration Address: 0x3804475d74a3b5261b34d3c8f31af30055058466
    ✓ 1. create new arbitration - state is unsigned (304ms)
    ✓ 2. approve arbitration for transfers (147ms)
    ✓ 3. only parties can sign arbitration (114ms)
    ✓ 4. party1 signs arbitration (134ms)
    ✓ 5. party1 unsigns arbitration (60ms)
    ✓ 6. party1 resigns arbitration (115ms)
    ✓ 7. party2 signs arbitration - state is now Signed (116ms)
    ✓ 8. only parties can agree arbitration
    ✓ 9. party2 agrees arbitration (86ms)
    ✓ 10. party1 agrees arbitration - state is now Agreed (83ms)
    ✓ 11. only parties can withdraw dispersals
    ✓ 12. party1 withdraws dispersal (zero tokens) (111ms)
    ✓ 13. party2 withdraws dispersal (150 tokens) - state is now Closed (130ms)

  Contract: Arbitration - Amendment with no dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0xe254a552ddf1d3cd5db6a1a69a8d7626402e4271
    ✓ 0. initialize token contract and arbitration factory contract (399ms)
Arbitration Address: 0x3804475d74a3b5261b34d3c8f31af30055058466
    ✓ 1. create new arbitration - state is unsigned (352ms)
    ✓ 2. approve arbitration for transfers (133ms)
    ✓ 3. only parties can sign arbitration (124ms)
    ✓ 4. party1 signs arbitration (87ms)
    ✓ 5. party1 unsigns arbitration (72ms)
    ✓ 6. party1 resigns arbitration (174ms)
    ✓ 7. party2 signs arbitration - state is now Signed (156ms)
    ✓ 8. party2 proposes amendment (130ms)
    ✓ 9. party1 agrees amendment (271ms)
    ✓ 10. party1 proposes amendment without authorising additional funding - fail (78ms)
    ✓ 11. party1 proposes amendment with authorised additional amendedFunding (247ms)
    ✓ 12. party2 agrees amendment (246ms)
    ✓ 13. party1 proposes amendment (257ms)
    ✓ 14. party1 unagrees amendment (137ms)
    ✓ 15. party1 agrees arbitration (99ms)
    ✓ 16. party2 agrees arbitration - state is now Agreed (88ms)
    ✓ 17. party1 withdraws dispersal (zero tokens) (112ms)
    ✓ 18. party2 withdraws dispersal (180 tokens) - state is now Closed (165ms)

  Contract: Arbitration - Refunded Amendment
JUR Token Address:  0x526dd75f0645fb6c071656b92c13e169214fe124
Arbitration Factory Address:  0x8fc1b1def5f7fef63e9bb4b33ac77b02b76a4a6f
    ✓ 0. initialize token contract and arbitration factory contract (366ms)
Arbitration Address: 0x794d28d7ae66a334ec589dd8dc25de9d8a43b412
    ✓ 1. create new arbitration - state is unsigned (166ms)
    ✓ 2. approve arbitration for transfers (120ms)
    ✓ 3. only parties can sign arbitration
    ✓ 4. party1 signs arbitration (60ms)
    ✓ 5. party1 unsigns arbitration (45ms)
    ✓ 6. party1 resigns arbitration (91ms)
    ✓ 7. party2 signs arbitration - state is now Signed (85ms)
    ✓ 8. party2 proposes amendment (74ms)
    ✓ 9. party1 agrees amendment (262ms)
    ✓ 10. party1 proposes amendment without authorising additional funding - fail (73ms)
    ✓ 11. party1 proposes amendment with authorised additional amendedFunding (234ms)
    ✓ 15. party1 agrees arbitration - party1 is refunded amendement funds (122ms)
    ✓ 16. party2 agrees arbitration - state is now Agreed (73ms)
    ✓ 17. party1 withdraws dispersal (twenty tokens) (101ms)
    ✓ 18. party2 withdraws dispersal (80 tokens) - state is now Closed (156ms)

  Contract: Arbitration - Tied dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0x738f23b326d12610a6374de0a12e3f5ce6b9eeca
    ✓ 0. initialize token contract and arbitration factory contract (545ms)
Arbitration Address: 0x4cd198d5d2c81a00fe1960fd6b8137fc39e7613a
    ✓ 1. create new arbitration - state is unsigned (296ms)
    ✓ 2. approve arbitration for transfers (260ms)
    ✓ 3. only parties can sign arbitration
    ✓ 4. party1 signs arbitration (91ms)
    ✓ 5. party2 signs arbitration - state is now Signed (117ms)
    ✓ 6. party1 disputes arbitration with sufficient vote (338ms)
    ✓ 7. party2 sets their dispute dispersal (226ms)
    ✓ 8. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION (112ms)
    ✓ 9. start voting resulting in a tie (405ms)
    ✓ 10. vote is extended due to a tie (113ms)
    ✓ 11. additional votes placed (under 5%) (226ms)
    ✓ 12. dispute ends, no more voting possible (119ms)
    ✓ 13. voters receive rewards (508ms)
    ✓ 14. parties receive payouts (572ms)

  Contract: Arbitration - Tied dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0x738f23b326d12610a6374de0a12e3f5ce6b9eeca
    ✓ 0. initialize token contract and arbitration factory contract (519ms)
Arbitration Address: 0x4cd198d5d2c81a00fe1960fd6b8137fc39e7613a
    ✓ 1. create new arbitration - state is unsigned (268ms)
    ✓ 2. approve arbitration for transfers (257ms)
    ✓ 3. only parties can sign arbitration (47ms)
    ✓ 4. party1 signs arbitration (101ms)
    ✓ 5. party2 signs arbitration - state is now Signed (121ms)
    ✓ 6. party1 disputes arbitration with sufficient vote (464ms)
    ✓ 7. party2 sets their dispute dispersal (219ms)
    ✓ 8. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION (105ms)
    ✓ 9. start voting (440ms)
    ✓ 10. vote is extended due to lots of votes during last 30 minutes (402ms)
    ✓ 11. unable to payout voters due to extended window (59ms)
    ✓ 12. able to vote during extended window (223ms)
    ✓ 13. voters receive rewards (693ms)
    ✓ 14. parties receive payouts (600ms)

  Contract: Arbitration - Approve and call
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0x738f23b326d12610a6374de0a12e3f5ce6b9eeca
    ✓ 0. initialize token contract and arbitration factory contract (739ms)
Arbitration Address: 0x4cd198d5d2c81a00fe1960fd6b8137fc39e7613a
    ✓ 1. create new arbitration - state is unsigned (266ms)
    ✓ 2. only parties can sign arbitration (85ms)
    ✓ 3. must send first argument as your own address (60ms)
    ✓ 4. party1 signs arbitration (129ms)
    ✓ 5. party2 signs arbitration - state is now Signed (145ms)
    ✓ 6. party1 disputes arbitration with sufficient vote (397ms)
    ✓ 7. party2 sets their dispute dispersal (202ms)
    ✓ 8. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION (94ms)
    ✓ 9. start voting (589ms)
    ✓ 10. unable to vote if ratio between new winner and second best is more than 2 (58ms)
    ✓ 11. dispute ends, no more voting possible (125ms)
    ✓ 12. voters receive rewards (502ms)
    ✓ 13. parties receive payouts (526ms)

  Contract: Arbitration - Reject dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0x738f23b326d12610a6374de0a12e3f5ce6b9eeca
    ✓ 0. initialize token contract and arbitration factory contract (524ms)
Arbitration Address: 0x4cd198d5d2c81a00fe1960fd6b8137fc39e7613a
    ✓ 1. create new arbitration - state is unsigned (257ms)
    ✓ 2. approve arbitration for transfers (300ms)
    ✓ 3. only parties can sign arbitration (47ms)
    ✓ 4. party1 signs arbitration (208ms)
    ✓ 5. party2 signs arbitration - state is now Signed (138ms)
    ✓ 6. party1 disputes arbitration with sufficient vote (367ms)
    ✓ 7. party2 sets their dispute dispersal (213ms)
    ✓ 8. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION (114ms)
    ✓ 9. start voting - reject option wins (471ms)
    ✓ 10. unable to vote if ratio between new winner and second best is more than 2 (76ms)
    ✓ 11. dispute ends, no more voting possible (117ms)
    ✓ 12. voters receive rewards (499ms)
    ✓ 13. parties receive payouts (493ms)

  Contract: Arbitration - Simple dispute
JUR Token Address:  0x1f37801d4db18b6a4cb6a65eced53ccb63ab764e
Arbitration Factory Address:  0x738f23b326d12610a6374de0a12e3f5ce6b9eeca
    ✓ 0. initialize token contract and arbitration factory contract (631ms)
Arbitration Address: 0x4cd198d5d2c81a00fe1960fd6b8137fc39e7613a
    ✓ 1. create new arbitration - state is unsigned (314ms)
    ✓ 2. approve arbitration for transfers (309ms)
    ✓ 3. only parties can sign arbitration (65ms)
    ✓ 4. party1 signs arbitration (124ms)
    ✓ 5. party2 signs arbitration - state is now Signed (141ms)
    ✓ 6. party1 disputes arbitration with insufficient vote - fail (208ms)
    ✓ 7. party1 disputes arbitration with sufficient vote (352ms)
    ✓ 8. party2 sets their dispute dispersal (238ms)
    ✓ 9. unable to change dispute dispersal after DISPUTE_DISPERSAL_DURATION (221ms)
    ✓ 10. start voting (788ms)
    ✓ 11. unable to vote if ratio between new winner and second best is more than 2 (127ms)
    ✓ 12. dispute ends, no more voting possible (152ms)
    ✓ 13. voters receive rewards (570ms)
    ✓ 14. parties receive payouts (605ms)


  106 passing (28s)
```
