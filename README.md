
# Proveably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. Users should be able to enter the raffle by paying for a ticket. The ticket fees are going to be the prize the winner receives.
2. The lottery should automatically and programmatically draw a winner after a certain period.
3. Chainlink VRF should generate a provably random number.

4. Chainlink Automation should trigger the lottery draw regularly.

## Test!

1. Writing deploy scripts
    1. Note, these will not work on zkSync(as of recording)
2. Write tests
    1. Local chain
    2. Forked testnet
    3. Forked mainnnet