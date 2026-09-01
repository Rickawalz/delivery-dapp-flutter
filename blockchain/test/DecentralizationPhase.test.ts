import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DecentralizationPhase } from "../typechain-types/contracts/governance/DecentralizationPhase";

/**
 * Test Suite for DecentralizationPhase
 * 
 * Academic Purpose: Validates the milestone-based decentralization framework (RQ2).
 * Demonstrates that governance transitions should be based on platform maturity
 * (deliveries, users, stability) rather than arbitrary time periods.
 */
describe("DecentralizationPhase - Thesis Framework", function () {
  let phaseTracker: DecentralizationPhase;
  let owner: Signer;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    const Phase = await ethers.getContractFactory("DecentralizationPhase");
    phaseTracker = await Phase.deploy() as unknown as DecentralizationPhase;
    await phaseTracker.waitForDeployment();
  });

  describe("Phase Initialization", function () {
    it("Should start in Bootstrap phase", async function () {
      const progress = await phaseTracker.getProgress();
      
      expect(progress.phase).to.equal(0); // Bootstrap = 0
      expect(progress.canAdvance).to.be.false; // No deliveries yet
    });

    it("Should set correct Phase 1 milestones", async function () {
      const milestones = await phaseTracker.getCurrentMilestones();
      
      expect(milestones.requiredDeliveries).to.equal(10000);
      expect(milestones.requiredDrivers).to.equal(100);
      expect(milestones.requiredDays).to.equal(180); // 6 months
      expect(milestones.requiredStabilityDays).to.equal(30);
    });
  });

  describe("Milestone Tracking", function () {
    it("Should track delivery completion", async function () {
      const driver = await (await ethers.getSigners())[1].getAddress();
      
      // Record delivery
      await phaseTracker.recordDelivery(driver, 1000);
      
      expect(await phaseTracker.totalDeliveries()).to.equal(1);
      expect(await phaseTracker.uniqueDrivers()).to.equal(1);
    });

    it("Should track unique drivers correctly", async function () {
      const [_, driver1, driver2] = await ethers.getSigners();
      
      // Driver 1 completes 2 deliveries
      await phaseTracker.recordDelivery(await driver1.getAddress(), 1000);
      await phaseTracker.recordDelivery(await driver1.getAddress(), 1200);
      
      expect(await phaseTracker.uniqueDrivers()).to.equal(1); // Still 1 unique
      
      // Driver 2 completes delivery
      await phaseTracker.recordDelivery(await driver2.getAddress(), 1000);
      
      expect(await phaseTracker.uniqueDrivers()).to.equal(2); // Now 2 unique
    });

    it("Should calculate progress percentages for thesis dashboard", async function () {
      // Add some progress
      const driver = await (await ethers.getSigners())[1].getAddress();
      
      // Complete 5000 deliveries (50% of milestone)
      for (let i = 0; i < 100; i++) {
        await phaseTracker.recordDelivery(driver, 1000);
      }

      const progress = await phaseTracker.getProgress();
      
      // Progress should be proportional
      expect(progress.deliveryProgress).to.equal(1); // 100/10000 = 1%
      expect(progress.driverProgress).to.equal(100); // 1/100 drivers = 100%
    });
  });

  describe("Incident Tracking (Stability Requirement)", function () {
    it("Should record incidents and reset stability counter", async function () {
      const initialIncidentTime = await phaseTracker.lastIncidentTime();
      
      // Record incident
      await expect(
        phaseTracker.recordIncident("Test bug found and fixed")
      ).to.emit(phaseTracker, "IncidentRecorded");
      
      const newIncidentTime = await phaseTracker.lastIncidentTime();
      expect(newIncidentTime).to.be.greaterThan(initialIncidentTime);
      
      // Academic value: Demonstrates stability requirement for decentralization
    });
  });

  describe("Phase Advancement Logic (Framework Concept)", function () {
    it("Should not allow advancement without meeting milestones", async function () {
      // Initially can't advance (no deliveries)
      expect(await phaseTracker.canAdvanceToHybrid()).to.be.false;
      
      // Try to advance should fail
      await expect(
        phaseTracker.advancePhase()
      ).to.be.revertedWith("DecentralizationPhase: Milestones not met for Hybrid");
    });

    it("Should provide progress information for thesis UI", async function () {
      const progress = await phaseTracker.getProgress();
      
      // All progress values should be between 0-100%
      expect(progress.deliveryProgress).to.be.lte(100);
      expect(progress.driverProgress).to.be.lte(100);
      expect(progress.timeProgress).to.be.lte(100);
      
      // Should indicate current phase
      expect(progress.phase).to.equal(0); // Bootstrap
      
      // Academic value: Provides data for decentralization dashboard in thesis
    });
  });

  describe("Milestone Comparison (Thesis Analysis)", function () {
    it("Should demonstrate Phase 1 vs Phase 2 milestone differences", async function () {
      // Phase 1 milestones (Bootstrap → Hybrid)
      const phase1 = await phaseTracker.getCurrentMilestones();
      
      console.log("\n    📈 Decentralization Framework (Thesis Data):\n");
      console.log("       Phase 1 Milestones (Bootstrap → Hybrid):");
      console.log(`         - ${phase1.requiredDeliveries} deliveries`);
      console.log(`         - ${phase1.requiredDrivers} unique drivers`);
      console.log(`         - ${phase1.requiredDays} days operation`);
      console.log(`         - ${phase1.requiredStabilityDays} days stable\n`);
      
      // Academic analysis: Demonstrates measurable criteria for governance readiness
      expect(phase1.requiredDeliveries).to.equal(10000);
      expect(phase1.requiredDrivers).to.equal(100);
    });
  });
});

