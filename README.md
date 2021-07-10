Request for Reorg (RFR)
===

This library creates a pattern for users to pay for miners to reorg the Ethereum blockchain.

How It Works
---

1. Users call the `request` function, specifying a past block number to be re-mined. The user attaches a `reward` amount to on the request, locking it the contract.
2. Miner re-mines the past block. They first include the `request` transaction (since the chain state is rolled back) and the `reorg` function, which gives the miner a claim on the reward.
3. After a set amount of block, the miner can call the `claim` function to claim the reward from the contract.

Slashing Mechanism
---

To use the example of a hack, if we wanted to create a bounty for the miner on-chain to prevent a hack, we would need the miner to exclude the outgoing transaction to the hacker's address. This behavior is not possible to enforce on-chain. To fix this, we use a slashing mechanism that gives the requester the ability to burn their rewards if the miner does not fulfill a certain behavior. 

For example, let's say Binance created a bounty for miners to stop an exchange hack. The miners go ahead to take Binance's reward from the contract, but still includes the hacker's transaction. Binance can take the high road by burning their own rewards. This ensures that the miner would waste mining power to create a reorg, but not get anything in return. This risk is enough for both parties to behave correctly.
