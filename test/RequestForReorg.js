const { assert } = require("chai");
const { ethers } = require("hardhat");

const START_BLOCK = 10;
const MINER_ADDRESS = "0xC014BA5EC014ba5ec014Ba5EC014ba5Ec014bA5E";
const provider = ethers.provider;

describe("RequestForReorg", function () {
  let rfr;
  let miner;
  let requesterSigner;
  let requester;

  before(async () => {
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
    it("creates a request", async () => {
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
      assert.equal(executeBlock.toNumber(), currentMinus10);
      assert.equal(expiryBlock.toNumber(), currentMinus5);
      assert.equal(reward.toString(), requestReward.toString());
    });
  });
});
