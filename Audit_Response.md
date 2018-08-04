# Audit Response - 4th August 2018

All fixes are included in the commit:  
https://github.com/jurteam/mvp-smart-contract/commit/c98aa7032a3b38d000c09cffb0d31462840c5765

## 2.1 - Timestamp Dependence

Agree that miners can impact on whether a vote is extended or not, by selectively censoring votes causing them to fall outside of the initial voting window, or not appear at all.

I think the risk here is small, and generally minor censoring of votes is a known issue with on-chain voting.

## 2.2 - Code Path Analysis

Resolved following the recommended approach of refunding (via `unagreeAmendment`) any funds deposited to cover an amended agreement if either party agrees or disputes the original (non-amended) agreement.

A test case has been added for this.

## 2.3 - External Contract Call Attacks

The `approveAndCall` function in `JURToken` only allows external calls to approved functions, and enforces that the first argument (or chunk of data) corresponds to the callers address. This allows called contracts to rely on calls from `JURToken` to be honest (correctly specify the callers address).

## 4 - Misc. Notes

  - `DisputeClosed` has been removed.

  - TODOs have been removed.

  - Comment on voting behaviour has been amended in `Arbitration.sol` and also added to `JUR Protocol Specification.md` to reflect the behaviour that a vote can not lead to the currently winning party having more than twice the next best party.

  - `accuracyDiv` has improved comments and been renamed to `decimalDiv`, and `decimalMul` has been added for consistency. These functions allow multiplication and division of decimals represented as decimals * 10**18. e.g. `decimalDiv(10 * 10**18, 100 * 10**18) == (10 / 100) * 10**18` and `decimalMul(0.5 * 10**18, 0.5 * 10**18) == 0.25 * 10**18`.
