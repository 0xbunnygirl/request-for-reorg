const { assert, expect } = require("chai");
const { ethers } = require("hardhat");

const START_BLOCK = 10;
const MINER_ADDRESS = "0xC014BA5EC014ba5ec014Ba5EC014ba5Ec014bA5E";
const provider = ethers.provider;

describe("RequestForReorg", function () {
  let rfr;
  let miner;
  let requesterSigner;
  let requester;

  beforeEach(async () => {
    [requesterSigner] = await ethers.getSigners();
    requester = requesterSigner.address;
    const RFR = await ethers.getContractFactory(
      "RequestForReorg",
      requesterSigner
    );
    rfr = await RFR.deploy();

    // Impersonate the default hardhat network miner
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [MINER_ADDRESS],
    });
    miner = await ethers.provider.getSigner(MINER_ADDRESS);

    for (let i = 0; i < START_BLOCK; i++) {
      await hre.network.provider.request({
        method: "evm_mine",
        params: [],
      });
    }
  });

  describe("request", () => {
    it("creates a request with executeBlock in the past", async () => {
      const currentBlock = await provider.getBlockNumber();
      const currentMinus10 = currentBlock - 10;
      const currentMinus5 = currentBlock - 5;
      const requestReward = ethers.utils.parseEther("1");

      await rfr.request(currentMinus10, currentMinus5, {
        value: requestReward,
      });

      const { claimant, executeBlock, expiryBlock, reward } =
        await rfr.requests(requester);

      assert.equal(claimant, ethers.constants.AddressZero);
      assert.equal(executeBlock, currentMinus10);
      assert.equal(expiryBlock, currentMinus5);
      assert.equal(reward.toString(), requestReward.toString());
    });

    it("creates a request with executeBlock right now", async () => {
      const currentBlock = await provider.getBlockNumber();
      const nextBlock = currentBlock + 1;
      const nextNextBlock = nextBlock + 1;

      await rfr.request(nextBlock, nextNextBlock);

      const { claimant, executeBlock, expiryBlock, reward } = await rfr.requests(requester);
      expect(claimant).to.equal(ethers.constants.AddressZero);
      expect(executeBlock).to.equal(nextBlock);
      expect(expiryBlock).to.equal(nextNextBlock);
      expect(reward).to.eq(0);
    });

    it("fails if request is created with an execution block in the future", async () => {
      const currentBlock = await provider.getBlockNumber();
      const nextBlock = currentBlock + 2;
      await expect(rfr.request(nextBlock, currentBlock)).to.be.revertedWith("executeBlock must be now, or in the past");

      // prove that `nextBlock` was a future block, at `request` execution time
      expect(nextBlock).to.equal((await provider.getBlockNumber()) + 1);
    });
  });
});
