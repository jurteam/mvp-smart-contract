# JUR Analysis

## Closed Hubs

A closed hub represents a group of JUR token holders who have a specific set of skills related to arbitration in common.

This group of JUR token holders deposit their tokens into a `ClosedHub` contract, and voting that utilises this closed hub are routed through the `ClosedHub` contract.

In addition to a `ClosedHub` contract instance for each closed hub group, there is a central `ClosedHubRepository` contract which records the list of all closed hub groups.

The `ClosedHubRepository` contract would have a data structure similar to the below (there is a single `ClosedHubRepository` instance):  
```
//Mapping from closed hub name to closed hub contract address
mapping (bytes32 => address) closedHubs;
```

Each `ClosedHub` contract instance would have a data structure similar to:  
```
//List of members in this closedHub
mapping (address => bool) closedHubMembers;
//Minimum escrow value an arbitration must have to use this closed hub
uint256 public minimumEscrow;
//Maximum escrow value an arbitration must have to use this closed hub
uint256 public maximumEscrow;
//Balances of JUR tokens staked to the contract by each member
mapping (address => uint256) balances;
```
and an API similar to:  
```
//Transfer (stake) tokens to the closed hub
function stakeTokens(uint256 _amount)
//Member votes through the closed hub, specifying the arbitration on which they are voting, and the party and amount of tokens they wish to vote with
function vote(address _arbitration, address _voteAddress, uint256 _voteAmount)
```

If a party wishes to, when setting up a new `Arbitration` contract, they can specify that they will only allow voting to originate from one or more closed hubs (as opposed to all JUR token holders). The `ArbitrationFactory` contract which is responsible for creating this new `Arbitration` contract would enforce that the arbitration fulfils the criteria to use a given closed hub (minimum / maximum escrowed amounts).

Each `ClosedHub` group can implement bespoke logic to restrict membership and the amount of tokens staked (and therefore eligable to be voted with) by each individual member.

For example, some closed hubs may have a single admin account, which is responsible for approving (or unapproving) each individual member. Alternatively it may be that, after the closed hub is first set up with a fixed list of members, new members are added via a voting process of existing members. The required quorum percentage and voting percentages would be specified by each individual closed hub (e.g. at least 30% of members must vote and of voting members, at least 70% must agree, in order for the vote to be valid).

The `ClosedHub` contracts can also enforce limits on the amount of tokens that can be staked to the contract by each individual member. For example, it could enforce that no single member has more than 25% of the total JUR tokens staked to the contract. These rules could be enforced continuously as members stake (or withdraw) tokens from the closed hub.

Members can, at any time, withdraw their staked JUR tokens from a closed hub in which they are a member.

Within an `Arbitration` contract, if it is initialised with a closed hub (or hubs) requirement, then the `Arbitration` contract would enforce that all voting happens through the specified closed hubs.

Within a closed hub group, it is possible for different members to vote differently on a given arbitration.

## Solving Scalability

Ethereum is the most mature blockchain that supports smart contract. However there are well-established scalability issues, with Ethereum currently supporting around 15 transactions per second (tps) meaning that when there is a high demand for network utilisation, viable gas prices often rise (as seen during the CryptoKitties launch). High gas prices can make the cost of transacting online (e.g. voting on arbitrations, or creating new arbitrations) prohibitively expensive.

Whilst there is a roadmap to improve scalability in Ethereum including layer 1 and layer 2 solutions (specifically Casper / proof-of-stake, sharding, plasma) it is worth considering what the possible alternatives are.

### Ethereum

It is possible to reduce on-chain transactions either via a “side-chain” using something like the Loom networks approach whereby most transactions occur off-chain in a proof of authority side-chain, with the main chain being used to secure the side-chain at well-defined checkpoints or by using state channels (e.g. Raiden) to facilitate peer-to-peer micro-payments. Both of these have advantages in terms of reducing on-chain transactions, but come with a cost of additional complexity. Both approaches are also relatively novel and have not yet been used in large scale production applications.

### EOS

EOS’s mainnet is due to launch imminently. EOS promises high rates of tps and a different approach to accounting for transaction costs (aka gas fees in Ethereum). Gas mechanics differ to Ethereum and Cardano where ETH or ADA is used to pay directly for transaction costs, and instead, by holding EOS tokens you are entitled to use a proportional amount of network bandwidth. Scaling is solved through dPoS, a more efficient, but less decentralised approach to consensus. Fast finalisation and low costs of transactions may make EOS an attractive option for dApps which rely on incentivising users to make on-chain transactions (such as voting in the JUR system).

### Cardano

Cardano focuses on a research driven approach, solving scalability through splitting settlement from computation and putting an emphasis on interoperability between blockchains. Their is a mainnet currently launched based on centralised block production, with a release scheduled to introduce the Ouroboros consensus algorithm (proof of stake) which would decentralise network security with the deployment of the computation layer scheduled after this. Migrating to Cardano has the benefit that Smart Contracts written in Solidity should be deployable to Cardano (which is also developing its own native language) and the emphasis on blockchain interoperability may facilitate a smoother switch from Ethereum via atomic token swaps or similar mechanisms.

### Summary

Today, Ethereum is the clear choice for any dApp MVP. It has mature tooling, an active development community and a large base of potential users. Desktop wallet options such as MetaMask and mobile options such as Cipher, Trust & Status-IM give users relatively easy UX’s to interact with dApps. Once it becomes necessary to truly scale however it may well be that other blockchains offer better features at a lower cost, with very similar benefits with respect to decentralisation and transfer of value.

## Smart Contract Architecture

This is largely already covered in the smart contract specification. There would be 3 contracts:  

  - JUR Token  
  - Arbitration Factory  
  - Arbitration [of which there will be multiple instances, one per arbitration]  

Closed Hubs could either be built into the Arbitration Factory, or put into a separate contract as per above.

To support web2 integrations, it may be necessary to have a new type of Arbitration contract with the escrow part removed, or otherwise potentially use the same contract, just setting the escrowed values to 0 (which would still support dispute resolution).

## Uploading Proofs

As discussed, I can’t see any reason to store any evidence associated with a dispute on-chain. We should be storing a hash of the original agreement between the two parties so that if a dispute arises both parties can independently and unilaterally prove the contents of the original agreement. If the agreement is bilaterally amended, then the updated agreement hash is also stored.

Documents that form part of the dispute process are in any way subject to being contested, so there is no obvious advantage of storing those on-chain other than potentially for reporting purposes, but this could be managed off-chain.

## Roadmap

Items that should be on the roadmap post-ICO:

  - develop closed hub contracts providing the ability for closed hub owners / members to customise their hubs appropriately.

  - develop arbitration only (no escrow) arbitration contracts for integration with web2.0 clients.

  - allow escrow in non-JUR tokens (ETH & other ERC20 tokens, e.g. DAI)

  - continually monitor and improve arbitration parameters (time periods, minimum voting amounts) and modify if needed based on real life usage
