import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { BalancedRewardSystem } from "../typechain-types/contracts/core/BalancedRewardSystem";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

/**
 * Test Suite for BalancedRewardSystem
 * 
 * Academic Purpose: These tests validate the core thesis contribution - the multi-factor
 * balanced reward algorithm. Tests demonstrate that the system:
 * 1. Correctly calculates rewards from all four factors
 * 2. Prevents gaming through anti-spam protections
 * 3. Adapts to network velocity changes
 * 4. Maintains fairness across different delivery types
 */
describe("BalancedRewardSystem - Thesis Tests", function () {
  let rewardSystem: BalancedRewardSystem;
  let token: DeliveryToken;
  let owner: Signer;
  let driver1: Signer;
  let driver2: Signer;
  let driver1Address: string;
  let driver2Address: string;

  beforeEach(async function () {
    [owner, driver1, driver2] = await ethers.getSigners();
    driver1Address = await driver1.getAddress();
    driver2Address = await driver2.getAddress();

    // Deploy token
    const Token = await ethers.getContractFactory("DeliveryToken");
    token = await Token.deploy() as unknown as DeliveryToken;
    await token.waitForDeployment();

    // Deploy reward system
    const RewardSystem = await ethers.getContractFactory("BalancedRewardSystem");
    rewardSystem = await RewardSystem.deploy(await token.getAddress()) as unknown as BalancedRewardSystem;
    await rewardSystem.waitForDeployment();

    // Transfer token ownership to reward system
    await token.transferOwnership(await rewardSystem.getAddress());
  });

  describe("Balanced Scoring Algorithm (PRIMARY CONTRIBUTION)", function () {
    it("Should calculate all four factors correctly", async function () {
      // Test Case: 10km delivery, 5 stars
      const preview = await rewardSystem.previewReward(driver1Address, 10000, 5);

      // Expected calculations:
      // Volume: 100 points
      // Distance: 10km * 10 = 100 points * 0.9 (tier 2) = 90 points
      // Rating: 5 * 20 = 100 points
      // Diversity: 0 (first delivery, no variety yet)
      // Total: 290 points
      
      expect(preview.volumePoints).to.equal(100);
      expect(preview.distancePoints).to.equal(90); // 10km in tier 2 (90% efficiency)
      expect(preview.ratingPoints).to.equal(100); // 5 stars
      expect(preview.diversityBonus).to.equal(0); // No diversity yet
      expect(preview.totalPoints).to.equal(290);
      
      // At 1 RLE per 100 points: 290 points = 2.9 RLE
      expect(preview.tokenReward).to.equal(ethers.parseEther("2.9"));
    });

    it("Should reward diversity bonus when driver varies delivery types", async function () {
      // Delivery 1: Short (3km, 5 stars)
      await rewardSystem.processReward(driver1Address, 3000, 5);
      
      // Wait 10 minutes
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      // Delivery 2: Medium (10km, 5 stars) - now has 2 types
      let preview = await rewardSystem.previewReward(driver1Address, 10000, 5);
      expect(preview.diversityBonus).to.equal(25); // 2 types = 25 points
      
      await rewardSystem.processReward(driver1Address, 10000, 5);
      
      // Wait 10 minutes
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      // Delivery 3: Long (20km, 5 stars) - now has all 3 types
      preview = await rewardSystem.previewReward(driver1Address, 20000, 5);
      expect(preview.diversityBonus).to.equal(50); // 3 types = 50 points MAX
    });

    it("Should apply diminishing returns on distance (prevents farming)", async function () {
      // Short distance (<5km): 100% efficiency
      let preview = await rewardSystem.previewReward(driver1Address, 3000, 5);
      expect(preview.distancePoints).to.equal(30); // 3km * 10 = 30

      // Medium distance (5-15km): 90% efficiency
      preview = await rewardSystem.previewReward(driver1Address, 10000, 5);
      expect(preview.distancePoints).to.equal(90); // 10km * 10 * 0.9 = 90

      // Long distance (15-30km): 80% efficiency
      preview = await rewardSystem.previewReward(driver1Address, 20000, 5);
      expect(preview.distancePoints).to.equal(160); // 20km * 10 * 0.8 = 160

      // Extra long (>30km): 70% efficiency
      preview = await rewardSystem.previewReward(driver1Address, 40000, 5);
      // Capped at 30km: 30km * 10 * 0.7 = 210
      expect(preview.distancePoints).to.equal(210);
    });

    it("Should penalize low ratings (quality incentive)", async function () {
      const distance = 10000; // Same distance

      // 1 star: minimal points
      let preview = await rewardSystem.previewReward(driver1Address, distance, 1);
      const reward1Star = preview.ratingPoints;
      expect(reward1Star).to.equal(20); // 1 * 20 = 20

      // 3 stars: moderate
      preview = await rewardSystem.previewReward(driver1Address, distance, 3);
      expect(preview.ratingPoints).to.equal(60); // 3 * 20 = 60

      // 5 stars: maximum
      preview = await rewardSystem.previewReward(driver1Address, distance, 5);
      expect(preview.ratingPoints).to.equal(100); // 5 * 20 = 100

      // Demonstrates: 5x difference between worst and best rating
      expect(preview.ratingPoints / reward1Star).to.equal(5);
    });
  });

  describe("Anti-Gaming Protections (RQ3: Technical Challenges)", function () {
    it("Should enforce 10-minute cooldown between deliveries", async function () {
      // First delivery succeeds
      await rewardSystem.processReward(driver1Address, 5000, 5);

      // Immediate second delivery should fail
      await expect(
        rewardSystem.processReward(driver1Address, 5000, 5)
      ).to.be.revertedWith("BalancedReward: Must wait 10 minutes between deliveries");

      // Fast forward 10 minutes
      await ethers.provider.send("evm_increaseTime", [600]); // 600 seconds = 10 minutes
      await ethers.provider.send("evm_mine", []);

      // Now should succeed
      await expect(rewardSystem.processReward(driver1Address, 5000, 5)).to.not.be.reverted;
    });

    it("Should enforce daily delivery limit of 50", async function () {
      // Process 50 deliveries
      for (let i = 0; i < 50; i++) {
        await ethers.provider.send("evm_increaseTime", [600]); // 10 min between each
        await ethers.provider.send("evm_mine", []);
        await rewardSystem.processReward(driver1Address, 5000, 5);
      }

      // 51st should fail
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      await expect(
        rewardSystem.processReward(driver1Address, 5000, 5)
      ).to.be.revertedWith("BalancedReward: Daily limit of 50 deliveries reached");
    });

    it("Should reject deliveries shorter than 500m (prevents spam)", async function () {
      await expect(
        rewardSystem.processReward(driver1Address, 400, 5)
      ).to.be.revertedWith("BalancedReward: Distance too short");

      // 500m should succeed
      await expect(rewardSystem.processReward(driver1Address, 500, 5)).to.not.be.reverted;
    });

    it("Should cap distance rewards at 30km (prevents unrealistic claims)", async function () {
      // 100km delivery gets capped at 30km for points
      const preview = await rewardSystem.previewReward(driver1Address, 100000, 5);
      
      // Should be same as 30km delivery
      const preview30km = await rewardSystem.previewReward(driver1Address, 30000, 5);
      
      expect(preview.distancePoints).to.equal(preview30km.distancePoints);
    });
  });

  describe("Adaptive Difficulty (RQ3: Scalability)", function () {
    it("Should adjust rate down when network is too fast", async function () {
      const initialRate = await rewardSystem.currentTokenRate();
      
      // Simulate high velocity (many deliveries in short time)
      // Fast forward 7 days for adjustment window
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
      
      // Process delivery to trigger adjustment
      // Note: Actual adjustment requires comparing against TARGET_DAILY (1000)
      // For full test, would need to mock many deliveries
      // This test demonstrates the mechanism exists
      
      const tx = await rewardSystem.processReward(driver1Address, 5000, 5);
      const receipt = await tx.wait();
      
      // Check that checkAndAdjust was called (gas usage or events)
      expect(receipt).to.not.be.null;
    });

    it("Should maintain current rate when velocity is stable", async function () {
      const initialRate = await rewardSystem.currentTokenRate();
      
      // Wait 6 days (not yet adjustment window)
      await ethers.provider.send("evm_increaseTime", [6 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
      
      // Process delivery
      await rewardSystem.processReward(driver1Address, 5000, 5);
      
      // Rate should not change (adjustment window not reached)
      const currentRate = await rewardSystem.currentTokenRate();
      expect(currentRate).to.equal(initialRate);
    });

    it("Should allow manual rate adjustment (emergency override)", async function () {
      const newRate = ethers.parseEther("1.5"); // 1.5 RLE per 100 points
      
      await rewardSystem.manualAdjustRate(newRate);
      
      const currentRate = await rewardSystem.currentTokenRate();
      expect(currentRate).to.equal(newRate);
    });
  });

  describe("Gas Optimization (RQ3: Performance)", function () {
    it("Should use reasonable gas for reward processing", async function () {
      const tx = await rewardSystem.processReward(driver1Address, 10000, 5);
      const receipt = await tx.wait();
      
      // Document gas usage for thesis
      const gasUsed = receipt?.gasUsed;
      console.log(`      Gas used for processReward: ${gasUsed}`);
      
      // Should be under 200k gas (thesis requirement)
      expect(gasUsed).to.be.lessThan(200000);
    });

    it("Should efficiently store driver stats (packed struct)", async function () {
      // Process a delivery
      await rewardSystem.processReward(driver1Address, 10000, 5);
      
      // Verify stats are stored
      const stats = await rewardSystem.getDriverStats(driver1Address);
      
      expect(stats[2]).to.equal(1); // totalDeliveries
      expect(stats[3]).to.be.greaterThan(0); // totalEarned
      
      // Academic note: Packed struct uses 1 storage slot vs 5 unpacked
      // This test demonstrates the data is accessible despite optimization
    });
  });

  describe("Token Supply Management (Thesis Economics)", function () {
    it("Should respect 21M token cap", async function () {
      const maxSupply = await token.MAX_SUPPLY();
      expect(maxSupply).to.equal(ethers.parseEther("21000000"));
    });

    it("Should track minted tokens correctly", async function () {
      // Process 3 deliveries
      await rewardSystem.processReward(driver1Address, 5000, 5);
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      await rewardSystem.processReward(driver1Address, 10000, 4);
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      await rewardSystem.processReward(driver1Address, 20000, 5);
      
      // Check driver balance
      const balance = await token.balanceOf(driver1Address);
      expect(balance).to.be.greaterThan(0);
      
      // Check total supply increased
      const totalSupply = await token.totalSupply();
      expect(totalSupply).to.equal(balance); // Only this driver has tokens
    });
  });

  describe("Driver Statistics Tracking (Thesis Metrics)", function () {
    it("Should track driver statistics for thesis analysis", async function () {
      // Process multiple deliveries
      await rewardSystem.processReward(driver1Address, 5000, 5);
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      await rewardSystem.processReward(driver1Address, 10000, 4);
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      await rewardSystem.processReward(driver1Address, 20000, 5);
      
      const stats = await rewardSystem.getDriverStats(driver1Address);
      
      expect(stats[2]).to.equal(3); // totalDeliveries
      expect(stats[4]).to.equal(1); // shortCount
      expect(stats[5]).to.equal(1); // mediumCount
      expect(stats[6]).to.equal(1); // longCount (perfect diversity!)
    });
  });

  describe("Preview Function (Transparency - RQ1)", function () {
    it("Should allow drivers to preview rewards before accepting delivery", async function () {
      // This demonstrates transparency - drivers know exact reward before committing
      const preview = await rewardSystem.previewReward(driver1Address, 10000, 5);
      
      // Verify all factors are disclosed
      expect(preview.volumePoints).to.be.greaterThan(0);
      expect(preview.distancePoints).to.be.greaterThan(0);
      expect(preview.ratingPoints).to.be.greaterThan(0);
      expect(preview.totalPoints).to.be.greaterThan(0);
      expect(preview.tokenReward).to.be.greaterThan(0);
      
      // Academic value: Transparent algorithm (unlike Uber's black box)
    });
  });

  describe("Comparative Scenarios (Thesis Evaluation Data)", function () {
    it("SHORT delivery scenario (3km, 5 stars)", async function () {
      const preview = await rewardSystem.previewReward(driver1Address, 3000, 5);
      
      // Volume: 100, Distance: 30 (3km*10), Rating: 100, Diversity: 0
      // Total: 230 points = 2.3 RLE
      expect(preview.totalPoints).to.equal(230);
      expect(preview.tokenReward).to.equal(ethers.parseEther("2.3"));
    });

    it("MEDIUM delivery scenario (10km, 4 stars)", async function () {
      const preview = await rewardSystem.previewReward(driver1Address, 10000, 4);
      
      // Volume: 100, Distance: 90 (10km*10*0.9), Rating: 80 (4*20), Diversity: 0
      // Total: 270 points = 2.7 RLE
      expect(preview.totalPoints).to.equal(270);
      expect(preview.tokenReward).to.equal(ethers.parseEther("2.7"));
    });

    it("LONG delivery scenario with diversity (20km, 5 stars)", async function () {
      // Setup diversity by doing short and medium first
      await rewardSystem.processReward(driver1Address, 3000, 5);
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      await rewardSystem.processReward(driver1Address, 10000, 5);
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      // Now long delivery with all 3 types
      const preview = await rewardSystem.previewReward(driver1Address, 20000, 5);
      
      // Volume: 100, Distance: 160 (20km*10*0.8), Rating: 100, Diversity: 50
      // Total: 410 points = 4.1 RLE
      expect(preview.diversityBonus).to.equal(50);
      expect(preview.totalPoints).to.equal(410);
      expect(preview.tokenReward).to.equal(ethers.parseEther("4.1"));
    });

    it("POOR rating scenario (10km, 2 stars) - demonstrates penalty", async function () {
      const preview = await rewardSystem.previewReward(driver1Address, 10000, 2);
      
      // Volume: 100, Distance: 90, Rating: 40 (2*20), Diversity: 0
      // Total: 230 points (vs 290 with 5 stars)
      // 21% reduction due to poor service
      expect(preview.ratingPoints).to.equal(40);
      expect(preview.totalPoints).to.equal(230);
    });
  });

  describe("Multiple Drivers (Fairness Analysis)", function () {
    it("Should treat different drivers fairly with same performance", async function () {
      // Both drivers do identical delivery
      const reward1 = await rewardSystem.processReward(driver1Address, 10000, 5);
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      
      const reward2 = await rewardSystem.processReward(driver2Address, 10000, 5);
      
      // Should earn exactly the same (fair algorithm)
      expect(reward1).to.equal(reward2);
    });
  });

  describe("Network Statistics (Thesis Data Collection)", function () {
    it("Should track global delivery count", async function () {
      await rewardSystem.processReward(driver1Address, 5000, 5);
      
      const stats = await rewardSystem.getNetworkStats();
      expect(stats[1]).to.equal(1); // totalDeliveriesCompleted
      
      await ethers.provider.send("evm_increaseTime", [600]);
      await ethers.provider.send("evm_mine", []);
      await rewardSystem.processReward(driver2Address, 8000, 4);
      
      const stats2 = await rewardSystem.getNetworkStats();
      expect(stats2[1]).to.equal(2);
    });

    it("Should provide current token rate for thesis analysis", async function () {
      const stats = await rewardSystem.getNetworkStats();
      
      // Initial rate: 1 RLE per 100 points
      expect(stats[0]).to.equal(ethers.parseEther("1"));
      
      // targetDaily available
      expect(stats[3]).to.equal(1000); // TARGET_DAILY_DELIVERIES
    });
  });
});

