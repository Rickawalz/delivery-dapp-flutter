import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { StakingManager } from "../typechain-types/contracts/core/StakingManager";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

describe("StakingManager", function () {
  let stakingManager: StakingManager;
  let deliveryToken: DeliveryToken;
  let owner: Signer;
  let courier1: Signer;
  let courier2: Signer;
  let ownerAddress: string;
  let courier1Address: string;
  let courier2Address: string;

  const STAKE_AMOUNT = ethers.parseEther("100"); // 100 tokens
  const LOCK_PERIOD = 30 * 24 * 60 * 60; // 30 days in seconds

  beforeEach(async function () {
    // Get signers
    [owner, courier1, courier2] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    courier1Address = await courier1.getAddress();
    courier2Address = await courier2.getAddress();

    // Deploy DeliveryToken
    const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
    deliveryToken = await DeliveryToken.deploy() as unknown as DeliveryToken;
    await deliveryToken.waitForDeployment();

    // Deploy StakingManager
    const StakingManager = await ethers.getContractFactory("StakingManager");
    stakingManager = await StakingManager.deploy(await deliveryToken.getAddress()) as unknown as StakingManager;
    await stakingManager.waitForDeployment();

    // Mint tokens for testing
    await deliveryToken.mint(courier1Address, STAKE_AMOUNT);
    await deliveryToken.mint(courier2Address, STAKE_AMOUNT);

    // Approve StakingManager to spend tokens
    await deliveryToken.connect(courier1).approve(await stakingManager.getAddress(), STAKE_AMOUNT);
    await deliveryToken.connect(courier2).approve(await stakingManager.getAddress(), STAKE_AMOUNT);
  });

  describe("Staking", function () {
    it("Should allow couriers to stake tokens", async function () {
      await stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD);

      const stakeInfo = await stakingManager.getStakeInfo(courier1Address);
      expect(stakeInfo.amount).to.equal(STAKE_AMOUNT);
      expect(stakeInfo.lockPeriod).to.equal(LOCK_PERIOD);
    });

    it("Should fail if stake amount is below minimum", async function () {
      const smallAmount = ethers.parseEther("50"); // Below MINIMUM_STAKE
      await expect(
        stakingManager.connect(courier1).stake(smallAmount, LOCK_PERIOD)
      ).to.be.revertedWith("Below minimum stake");
    });

    it("Should fail if lock period is too short", async function () {
      const shortPeriod = 29 * 24 * 60 * 60; // 29 days
      await expect(
        stakingManager.connect(courier1).stake(STAKE_AMOUNT, shortPeriod)
      ).to.be.revertedWith("Lock period too short");
    });

    it("Should fail if courier has insufficient balance", async function () {
      const largeAmount = ethers.parseEther("1000");
      // Reset allowance first
      await deliveryToken.connect(courier1).approve(await stakingManager.getAddress(), largeAmount);
      await expect(
        stakingManager.connect(courier1).stake(largeAmount, LOCK_PERIOD)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("Should fail if courier has insufficient allowance", async function () {
      // Reset allowance
      await deliveryToken.connect(courier1).approve(await stakingManager.getAddress(), 0);

      await expect(
        stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD)
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });

    it("Should fail if courier already has a stake", async function () {
      await stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD);
      await expect(
        stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD)
      ).to.be.revertedWith("Already staked");
    });
  });

  describe("Unstaking", function () {
    beforeEach(async function () {
      await stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD);
    });

    it("Should allow couriers to unstake after lock period", async function () {
      // Fast forward time past lock period
      await ethers.provider.send("evm_increaseTime", [LOCK_PERIOD + 1]);
      await ethers.provider.send("evm_mine", []);

      await stakingManager.connect(courier1).unstake();

      const stakeInfo = await stakingManager.getStakeInfo(courier1Address);
      expect(stakeInfo[0]).to.equal(0); // amount
    });

    it("Should fail if trying to unstake before lock period ends", async function () {
      // Fast forward time, but not enough
      await ethers.provider.send("evm_increaseTime", [LOCK_PERIOD - 86400]); // One day less
      await ethers.provider.send("evm_mine", []);

      await expect(
        stakingManager.connect(courier1).unstake()
      ).to.be.revertedWith("Lock period not ended");
    });

    it("Should fail if no stake exists", async function () {
      await expect(
        stakingManager.connect(courier2).unstake()
      ).to.be.revertedWith("No stake found");
    });
  });

  describe("Rewards", function () {
    beforeEach(async function () {
      await stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD);
    });

    it("Should calculate rewards correctly", async function () {
      // Fast forward 1 year
      const oneYear = 365 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneYear]);
      await ethers.provider.send("evm_mine", []);

      const reward = await stakingManager.calculateReward(courier1Address);
      const expectedReward = (STAKE_AMOUNT * 5n * BigInt(oneYear)) / (365n * 24n * 60n * 60n * 100n);
      expect(reward).to.equal(expectedReward);
    });

    it("Should pay rewards on unstake", async function () {
      // Fast forward 1 year
      const oneYear = 365 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneYear + LOCK_PERIOD]);
      await ethers.provider.send("evm_mine", []);

      await stakingManager.connect(courier1).unstake();
      const reward = await stakingManager.calculateReward(courier1Address);
      expect(reward).to.equal(0); // Reward should be paid and reset
    });
  });

  describe("Slashing", function () {
    beforeEach(async function () {
      await stakingManager.connect(courier1).stake(STAKE_AMOUNT, LOCK_PERIOD);
    });

    it("Should allow owner to slash staked tokens", async function () {
      const slashAmount = ethers.parseEther("50");
      await stakingManager.connect(owner).slashStake(courier1Address, slashAmount, "Test slash");

      const stakeInfo = await stakingManager.getStakeInfo(courier1Address);
      expect(stakeInfo[0]).to.equal(STAKE_AMOUNT - slashAmount);
    });

    it("Should fail if non-owner tries to slash", async function () {
      const slashAmount = ethers.parseEther("50");
      await expect(
        stakingManager.connect(courier2).slashStake(courier1Address, slashAmount, "Test slash")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should fail if slash amount exceeds staked amount", async function () {
      const largeAmount = ethers.parseEther("1000");
      await expect(
        stakingManager.connect(owner).slashStake(courier1Address, largeAmount, "Test slash")
      ).to.be.revertedWith("Insufficient stake");
    });
  });
}); 