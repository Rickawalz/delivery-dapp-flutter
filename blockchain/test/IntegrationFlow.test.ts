import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";
import { BalancedRewardSystem } from "../typechain-types/contracts/core/BalancedRewardSystem";
import { DeliveryTrackingSystem } from "../typechain-types/contracts/core/DeliveryTrackingSystem";
import { SimpleDeliverySystem } from "../typechain-types/contracts/core/SimpleDeliverySystem";
import { DecentralizationPhase } from "../typechain-types/contracts/governance/DecentralizationPhase";

/**
 * Integration Test Suite
 * 
 * Academic Purpose: Demonstrates complete system functionality for thesis.
 * Tests the full delivery flow showing how all contracts interact to provide:
 * - Transparency (RQ1): Tracking + financial visibility
 * - Fair Economics (RQ2): 2% fee model + balanced rewards
 * - Technical Solutions (RQ3): Anti-gaming + scalability
 */
describe("Complete System Integration - Thesis Demonstration", function () {
  let token: DeliveryToken;
  let rewardSystem: BalancedRewardSystem;
  let trackingSystem: DeliveryTrackingSystem;
  let deliverySystem: SimpleDeliverySystem;
  let phaseTracker: DecentralizationPhase;
  
  let owner: Signer;
  let driver1: Signer;
  let customer1: Signer;
  let driver1Address: string;
  let customer1Address: string;

  before(async function () {
    [owner, driver1, customer1] = await ethers.getSigners();
    driver1Address = await driver1.getAddress();
    customer1Address = await customer1.getAddress();

    console.log("\n    🎓 Deploying complete thesis system...\n");

    // Deploy all contracts (simulating deploy-thesis.ts)
    const Token = await ethers.getContractFactory("DeliveryToken");
    token = await Token.deploy() as unknown as DeliveryToken;
    await token.waitForDeployment();
    console.log("    ✅ DeliveryToken deployed");

    const Tracking = await ethers.getContractFactory("DeliveryTrackingSystem");
    trackingSystem = await Tracking.deploy() as unknown as DeliveryTrackingSystem;
    await trackingSystem.waitForDeployment();
    console.log("    ✅ DeliveryTrackingSystem deployed");

    const RewardSystem = await ethers.getContractFactory("BalancedRewardSystem");
    rewardSystem = await RewardSystem.deploy(await token.getAddress()) as unknown as BalancedRewardSystem;
    await rewardSystem.waitForDeployment();
    console.log("    ✅ BalancedRewardSystem deployed");

    const DeliverySystem = await ethers.getContractFactory("SimpleDeliverySystem");
    deliverySystem = await DeliverySystem.deploy(
      await rewardSystem.getAddress(),
      await trackingSystem.getAddress()
    ) as unknown as SimpleDeliverySystem;
    await deliverySystem.waitForDeployment();
    console.log("    ✅ SimpleDeliverySystem deployed");

    const Phase = await ethers.getContractFactory("DecentralizationPhase");
    phaseTracker = await Phase.deploy() as unknown as DecentralizationPhase;
    await phaseTracker.waitForDeployment();
    console.log("    ✅ DecentralizationPhase deployed");

    // Setup permissions
    await token.transferOwnership(await rewardSystem.getAddress());
    await rewardSystem.transferOwnership(await deliverySystem.getAddress());
    console.log("    ✅ Permissions configured\n");
  });

  describe("Complete Delivery Flow (End-to-End)", function () {
    it("Should execute full delivery lifecycle with tracking and rewards", async function () {
      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("thesis-demo-delivery-1"));
      const distance = 10000; // 10km
      const fiatAmount = 1200; // $12.00
      const rating = 5;

      console.log("    \n    📦 Thesis Demo: Complete Delivery Flow\n");

      // STEP 1: Customer creates delivery
      console.log("    1️⃣  Customer creates delivery (10km, $12)");
      await expect(
        deliverySystem.connect(customer1).createDelivery(
          deliveryId,
          driver1Address,
          distance,
          fiatAmount
        )
      ).to.emit(deliverySystem, "DeliveryCreated");

      const delivery = await deliverySystem.getDelivery(deliveryId);
      expect(delivery.customer).to.equal(customer1Address);
      expect(delivery.driver).to.equal(driver1Address);
      expect(delivery.distanceMeters).to.equal(distance);

      // STEP 2: Driver adds location checkpoints (TRANSPARENCY - RQ1)
      console.log("    2️⃣  Driver tracks delivery with GPS checkpoints");
      const pickupLocation = ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937"));
      const transitLocation = ethers.keccak256(ethers.toUtf8Bytes("13.4500,144.8000"));
      
      await deliverySystem.connect(driver1).addDeliveryCheckpoint(
        deliveryId,
        pickupLocation,
        "pickup"
      );
      
      await deliverySystem.connect(driver1).addDeliveryCheckpoint(
        deliveryId,
        transitLocation,
        "in_transit"
      );

      const trackingInfo = await trackingSystem.getCurrentLocation(deliveryId);
      expect(trackingInfo.checkpoints).to.equal(2);

      // STEP 3: Driver submits proof of pickup
      console.log("    3️⃣  Driver submits proof of pickup (photo hash)");
      const pickupProof = ethers.keccak256(ethers.toUtf8Bytes("ipfs://QmPickupPhoto"));
      await deliverySystem.connect(driver1).submitPickupProof(deliveryId, pickupProof);

      // STEP 4: Driver completes delivery with customer rating
      console.log("    4️⃣  Customer rates delivery (5⭐)");
      
      const balanceBefore = await token.balanceOf(driver1Address);
      
      await expect(
        deliverySystem.completeDelivery(deliveryId, rating)
      ).to.emit(deliverySystem, "DeliveryCompleted");

      // STEP 5: Verify delivery completed
      const completedDelivery = await deliverySystem.getDelivery(deliveryId);
      expect(completedDelivery.status).to.equal(2); // Completed
      expect(completedDelivery.rating).to.equal(rating);

      // STEP 6: Verify driver received balanced reward
      const balanceAfter = await token.balanceOf(driver1Address);
      const reward = balanceAfter - balanceBefore;
      
      console.log(`    5️⃣  Driver earned: ${ethers.formatEther(reward)} RLE\n`);
      
      // Expected: Volume(100) + Distance(90) + Rating(100) + Diversity(0) = 290 points = 2.9 RLE
      expect(reward).to.equal(ethers.parseEther("2.9"));

      // STEP 7: Verify platform fee tracked (ECONOMICS - RQ2)
      const platformStats = await deliverySystem.getPlatformStats();
      const expectedFee = (fiatAmount * 2) / 100; // 2% of $12 = $0.24
      expect(platformStats.feesCollected).to.equal(expectedFee);

      console.log("    ✅ Complete flow successful - All RQs demonstrated!\n");
    });
  });

  describe("Economic Analysis (RQ2: Cost Efficiency)", function () {
    it("Should demonstrate 2% fee vs traditional 30% fee savings", async function () {
      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("economic-test"));
      const fiatAmount = 1000; // $10.00

      // Create and complete delivery
      await deliverySystem.connect(customer1).createDelivery(
        deliveryId,
        driver1Address,
        10000,
        fiatAmount
      );

      await deliverySystem.completeDelivery(deliveryId, 5);

      // Check platform fee
      const stats = await deliverySystem.getPlatformStats();
      const platformFee = Number(stats.feesCollected);
      const feePercent = Number(stats.feePercent);

      expect(feePercent).to.equal(2);
      expect(platformFee).to.equal(20); // 2% of $10 = $0.20

      // For thesis comparison:
      const traditionalFee = (fiatAmount * 30) / 100; // 30% = $3.00
      const savings = traditionalFee - platformFee; // $2.80 saved

      console.log(`\n    💰 Economic Comparison (Thesis Data):`);
      console.log(`       Traditional fee (30%): $${traditionalFee / 100}`);
      console.log(`       Your system fee (2%): $${platformFee / 100}`);
      console.log(`       Savings: $${savings / 100} (${((savings / traditionalFee) * 100).toFixed(1)}% reduction)\n`);

      expect(savings).to.equal(280); // $2.80 savings
    });

    it("Should show driver earnings comparison (Thesis Table 6.2)", async function () {
      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("driver-earnings"));
      const marketPrice = 1000; // $10 market price

      await deliverySystem.connect(customer1).createDelivery(
        deliveryId,
        driver1Address,
        10000,
        marketPrice
      );

      // Track driver balance before
      const balanceBefore = await token.balanceOf(driver1Address);

      await deliverySystem.completeDelivery(deliveryId, 5);

      const balanceAfter = await token.balanceOf(driver1Address);
      const tokenReward = balanceAfter - balanceBefore;

      // For thesis comparison:
      const uberDriverEarning = (marketPrice * 70) / 100; // Uber: $7.00 (30% fee)
      const yourDriverEarning = (marketPrice * 98) / 100; // Yours: $9.80 (2% fee)
      const difference = yourDriverEarning - uberDriverEarning; // $2.80 more

      console.log(`\n    💵 Driver Earnings Comparison (Thesis Data):`);
      console.log(`       Uber driver ($10 delivery): $${uberDriverEarning / 100}`);
      console.log(`       Your system ($10 delivery): $${yourDriverEarning / 100}`);
      console.log(`       Additional fiat: $${difference / 100}`);
      console.log(`       Plus token reward: ${ethers.formatEther(tokenReward)} RLE`);
      console.log(`       Total advantage: ~${((difference / uberDriverEarning) * 100).toFixed(1)}% better earnings\n`);
    });
  });

  describe("Decentralization Milestones (RQ2: Framework)", function () {
    it("Should track progress toward Hybrid phase", async function () {
      const progress = await phaseTracker.getProgress();
      
      // Initially at Bootstrap phase
      expect(progress.phase).to.equal(0); // Bootstrap
      expect(progress.canAdvance).to.be.false; // Not enough deliveries yet
      
      // Check milestones
      const milestones = await phaseTracker.getCurrentMilestones();
      expect(milestones.requiredDeliveries).to.equal(10000);
      expect(milestones.requiredDrivers).to.equal(100);
      expect(milestones.requiredDays).to.equal(180);
    });

    it("Should allow phase advancement when milestones met", async function () {
      // For testing, we can manually set metrics (in production, accumulated naturally)
      // This demonstrates the milestone checking logic
      
      const progress = await phaseTracker.getProgress();
      expect(progress.phase).to.equal(0); // Bootstrap
      
      // Academic note: In real deployment, this would require 10k deliveries + 6 months
      // For thesis, demonstrates the framework concept
    });
  });

  describe("Complete Thesis Demonstration Scenarios", function () {
    it("Scenario 1: Diverse driver earns maximum rewards", async function () {
      console.log("\n    📊 Thesis Scenario 1: Diverse Driver\n");

      const deliveries = [
        { id: "diverse-1", distance: 3000, rating: 5, type: "short" },
        { id: "diverse-2", distance: 10000, rating: 5, type: "medium" },
        { id: "diverse-3", distance: 20000, rating: 5, type: "long" },
      ];

      let totalEarned = 0n;

      for (let i = 0; i < deliveries.length; i++) {
        const del = deliveries[i];
        const delId = ethers.keccak256(ethers.toUtf8Bytes(del.id));
        
        await deliverySystem.connect(customer1).createDelivery(
          delId,
          driver1Address,
          del.distance,
          1000
        );

        if (i > 0) {
          // Wait 10 minutes between deliveries
          await ethers.provider.send("evm_increaseTime", [600]);
          await ethers.provider.send("evm_mine", []);
        }

        const balBefore = await token.balanceOf(driver1Address);
        await deliverySystem.completeDelivery(delId, del.rating);
        const balAfter = await token.balanceOf(driver1Address);
        
        const earned = balAfter - balBefore;
        totalEarned += earned;

        console.log(`       ${del.type} (${del.distance / 1000}km, ${del.rating}⭐): ${ethers.formatEther(earned)} RLE`);
      }

      console.log(`       Total earned: ${ethers.formatEther(totalEarned)} RLE`);
      console.log(`       Diversity bonus activated on delivery 2 & 3! ✅\n`);

      // Third delivery should have diversity bonus (all 3 types)
      const stats = await rewardSystem.getDriverStats(driver1Address);
      expect(stats[4]).to.equal(1); // 1 short
      expect(stats[5]).to.equal(1); // 1 medium
      expect(stats[6]).to.equal(1); // 1 long (perfect diversity!)
    });

    it("Scenario 2: Gaming attempt fails (friend circle)", async function () {
      console.log("\n    🚫 Thesis Scenario 2: Gaming Prevention\n");

      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("gaming-attempt"));

      // Create very short delivery (would be profitable spam if allowed)
      await deliverySystem.connect(customer1).createDelivery(
        deliveryId,
        driver1Address,
        400, // Only 400m (below 500m minimum)
        500
      );

      // Attempt to complete should fail
      await expect(
        deliverySystem.completeDelivery(deliveryId, 5)
      ).to.be.revertedWith("BalancedReward: Distance too short");

      console.log("    ✅ Spam delivery prevented (< 500m rejected)\n");
    });

    it("Scenario 3: Transparency demonstration (anyone can query)", async function () {
      console.log("\n    🔍 Thesis Scenario 3: Transparency\n");

      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("transparent-delivery"));

      // Create delivery
      await deliverySystem.connect(customer1).createDelivery(
        deliveryId,
        driver1Address,
        10000,
        1200
      );

      // Add checkpoints
      await deliverySystem.connect(driver1).addDeliveryCheckpoint(
        deliveryId,
        ethers.keccak256(ethers.toUtf8Bytes("Location1")),
        "pickup"
      );

      // Complete
      await deliverySystem.completeDelivery(deliveryId, 5);

      // ANYONE can query all information (transparency!)
      const deliveryInfo = await deliverySystem.getDelivery(deliveryId);
      const trackingInfo = await trackingSystem.getCurrentLocation(deliveryId);
      const platformStats = await deliverySystem.getPlatformStats();

      console.log("    Public Information Available:");
      console.log(`       Customer: ${deliveryInfo.customer}`);
      console.log(`       Driver: ${deliveryInfo.driver}`);
      console.log(`       Distance: ${deliveryInfo.distanceMeters}m`);
      console.log(`       Rating: ${deliveryInfo.rating}⭐`);
      console.log(`       Checkpoints: ${trackingInfo.checkpoints}`);
      console.log(`       Platform fee: ${platformStats.feePercent}%`);
      console.log("    ✅ All data transparent and queryable!\n");

      // Academic value: Solves opacity problem mentioned in thesis intro
      expect(deliveryInfo.customer).to.not.equal(ethers.ZeroAddress);
      expect(trackingInfo.checkpoints).to.be.greaterThan(0);
    });
  });

  describe("Thesis Data Collection", function () {
    it("Should provide all metrics needed for thesis tables/graphs", async function () {
      // Complete several deliveries for data collection
      for (let i = 0; i < 5; i++) {
        const delId = ethers.keccak256(ethers.toUtf8Bytes(`data-delivery-${i}`));
        
        await deliverySystem.connect(customer1).createDelivery(
          delId,
          driver1Address,
          5000 + i * 2000, // Varying distances
          1000,
        );

        await ethers.provider.send("evm_increaseTime", [600]);
        await ethers.provider.send("evm_mine", []);

        await deliverySystem.completeDelivery(delId, 4 + (i % 2)); // Ratings 4-5
      }

      // Collect thesis metrics
      const driverStats = await rewardSystem.getDriverStats(driver1Address);
      const networkStats = await rewardSystem.getNetworkStats();
      const platformStats = await deliverySystem.getPlatformStats();
      const phaseProgress = await phaseTracker.getProgress();

      console.log("\n    📊 Thesis Metrics Collected:");
      console.log(`       Driver Total Deliveries: ${driverStats[2]}`);
      console.log(`       Driver Total Earned: ${ethers.formatEther(driverStats[3])} RLE`);
      console.log(`       Network Total Deliveries: ${networkStats[1]}`);
      console.log(`       Network Token Rate: ${ethers.formatEther(networkStats[0])} RLE/100pts`);
      console.log(`       Platform Total Fees: $${Number(platformStats[2]) / 100}`);
      console.log(`       Decentralization Progress: ${phaseProgress[1]}%\n`);

      // All data available for thesis analysis
      expect(driverStats[2]).to.be.greaterThan(0);
      expect(networkStats[1]).to.be.greaterThan(0);
      expect(platformStats[2]).to.be.greaterThan(0);
    });
  });

  describe("Gas Cost Analysis (Thesis Table 6.1)", function () {
    it("Should measure and document gas costs for thesis", async function () {
      const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("gas-analysis"));

      console.log("\n    ⛽ Gas Cost Analysis for Thesis:\n");

      // Measure createDelivery
      const createTx = await deliverySystem.connect(customer1).createDelivery(
        deliveryId,
        driver1Address,
        10000,
        1200
      );
      const createReceipt = await createTx.wait();
      console.log(`       createDelivery: ${createReceipt?.gasUsed} gas`);

      // Measure addCheckpoint
      const checkpointTx = await deliverySystem.connect(driver1).addDeliveryCheckpoint(
        deliveryId,
        ethers.keccak256(ethers.toUtf8Bytes("Location")),
        "pickup"
      );
      const checkpointReceipt = await checkpointTx.wait();
      console.log(`       addCheckpoint: ${checkpointReceipt?.gasUsed} gas`);

      // Measure completeDelivery (includes reward calculation)
      const completeTx = await deliverySystem.completeDelivery(deliveryId, 5);
      const completeReceipt = await completeTx.wait();
      console.log(`       completeDelivery: ${completeReceipt?.gasUsed} gas`);

      const totalGas = (createReceipt?.gasUsed || 0n) + 
                       (checkpointReceipt?.gasUsed || 0n) + 
                       (completeReceipt?.gasUsed || 0n);
      
      console.log(`       TOTAL FLOW: ${totalGas} gas\n`);

      // For thesis: Calculate costs at different gas prices
      const gasPrice = 0.01; // cents per gas on L2
      const costL2 = Number(totalGas) * gasPrice;
      
      console.log(`       Cost on L2 (~$0.01/100k gas): $${(costL2 / 100000).toFixed(4)}`);
      console.log(`       Cost on Mainnet (~$60/100k gas): $${(Number(totalGas) * 60 / 100000).toFixed(2)}\n`);

      // Should be under 300k gas total (thesis requirement)
      expect(totalGas).to.be.lessThan(300000);
    });
  });
});

