import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { StakingManager } from "../typechain-types/contracts/core/StakingManager";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

/**
 * ARCHIVED: StakingManager test file
 * This test is archived because StakingManager contract is not used in the current MVP.
 * Kept for reference and potential future implementation.
 */
describe("StakingManager", function () {
  let stakingManager: StakingManager;
  let deliveryToken: DeliveryToken;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy DeliveryToken
    const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
    deliveryToken = await DeliveryToken.deploy();
    await deliveryToken.waitForDeployment();

    // Deploy StakingManager
    const StakingManager = await ethers.getContractFactory("StakingManager");
    stakingManager = await StakingManager.deploy(await deliveryToken.getAddress());
    await stakingManager.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right token address", async function () {
      expect(await stakingManager.deliveryToken()).to.equal(await deliveryToken.getAddress());
    });

    it("Should set the right owner", async function () {
      expect(await stakingManager.owner()).to.equal(await owner.getAddress());
    });

    it("Should have correct constants", async function () {
      expect(await stakingManager.MINIMUM_STAKE()).to.equal(ethers.parseEther("100"));
      expect(await stakingManager.MINIMUM_LOCK_PERIOD()).to.equal(30 * 24 * 60 * 60); // 30 days
      expect(await stakingManager.REWARD_RATE()).to.equal(5);
    });
  });

  describe("Staking", function () {
    beforeEach(async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, stakeAmount);

      // Approve staking manager to spend tokens
      await deliveryToken.connect(user1).approve(await stakingManager.getAddress(), stakeAmount);
    });

    it("Should allow staking", async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      await expect(stakingManager.connect(user1).stake(stakeAmount, lockPeriod))
        .to.emit(stakingManager, "Staked")
        .withArgs(user1Address, stakeAmount, lockPeriod);
    });

    it("Should fail with insufficient stake", async function () {
      const stakeAmount = ethers.parseEther("50"); // Below minimum
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      await expect(
        stakingManager.connect(user1).stake(stakeAmount, lockPeriod)
      ).to.be.revertedWith("Below minimum stake");
    });

    it("Should fail with short lock period", async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 10 * 24 * 60 * 60; // 10 days

      // Mint more tokens
      await deliveryToken.mint(user1Address, stakeAmount);

      await expect(
        stakingManager.connect(user1).stake(stakeAmount, lockPeriod)
      ).to.be.revertedWith("Lock period too short");
    });

    it("Should fail if already staked", async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      // First stake
      await stakingManager.connect(user1).stake(stakeAmount, lockPeriod);

      // Second stake should fail
      await expect(
        stakingManager.connect(user1).stake(stakeAmount, lockPeriod)
      ).to.be.revertedWith("Already staked");
    });
  });

  describe("Unstaking", function () {
    beforeEach(async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, stakeAmount);

      // Approve staking manager to spend tokens
      await deliveryToken.connect(user1).approve(await stakingManager.getAddress(), stakeAmount);

      // Stake
      await stakingManager.connect(user1).stake(stakeAmount, lockPeriod);
    });

    it("Should fail before lock period ends", async function () {
      await expect(
        stakingManager.connect(user1).unstake()
      ).to.be.revertedWith("Lock period not ended");
    });

    it("Should allow unstaking after lock period", async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");

      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // 30 days
      await ethers.provider.send("evm_mine", []);

      await expect(stakingManager.connect(user1).unstake())
        .to.emit(stakingManager, "Unstaked")
        .withArgs(user1Address, stakeAmount);
    });
  });

  describe("Reward Calculation", function () {
    beforeEach(async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, stakeAmount);

      // Approve staking manager to spend tokens
      await deliveryToken.connect(user1).approve(await stakingManager.getAddress(), stakeAmount);

      // Stake
      await stakingManager.connect(user1).stake(stakeAmount, lockPeriod);
    });

    it("Should calculate rewards correctly", async function () {
      const user1Address = await user1.getAddress();

      // Fast forward time by 1 day
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      const reward = await stakingManager.calculateReward(user1Address);
      expect(reward).to.be.gt(0);
    });
  });

  describe("Stake Slashing", function () {
    beforeEach(async function () {
      const user1Address = await user1.getAddress();
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60; // 30 days

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, stakeAmount);

      // Approve staking manager to spend tokens
      await deliveryToken.connect(user1).approve(await stakingManager.getAddress(), stakeAmount);

      // Stake
      await stakingManager.connect(user1).stake(stakeAmount, lockPeriod);
    });

    it("Should allow owner to slash stake", async function () {
      const user1Address = await user1.getAddress();
      const slashAmount = ethers.parseEther("10");
      const reason = "Violation of terms";

      await expect(stakingManager.slashStake(user1Address, slashAmount, reason))
        .to.emit(stakingManager, "StakeSlashed")
        .withArgs(user1Address, slashAmount, reason);
    });

    it("Should fail if slashing more than staked", async function () {
      const user1Address = await user1.getAddress();
      const slashAmount = ethers.parseEther("200"); // More than staked
      const reason = "Violation of terms";

      await expect(
        stakingManager.slashStake(user1Address, slashAmount, reason)
      ).to.be.revertedWith("Insufficient stake");
    });

    it("Should fail if non-owner tries to slash", async function () {
      const user1Address = await user1.getAddress();
      const slashAmount = ethers.parseEther("10");
      const reason = "Violation of terms";

      await expect(
        stakingManager.connect(user1).slashStake(user1Address, slashAmount, reason)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});









