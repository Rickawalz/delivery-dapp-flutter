import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliveryTrackingSystem } from "../typechain-types/contracts/core/DeliveryTrackingSystem";

/**
 * Test Suite for DeliveryTrackingSystem
 * 
 * Academic Purpose: Validates the tracking system that addresses RQ1 (transparency).
 * Demonstrates that blockchain can solve the "Guam container problem" through
 * immutable location tracking and proof of delivery.
 */
describe("DeliveryTrackingSystem - Thesis Tests", function () {
  let tracking: DeliveryTrackingSystem;
  let owner: Signer;
  let driver: Signer;
  let customer: Signer;
  let driverAddress: string;
  let customerAddress: string;

  const deliveryId = ethers.keccak256(ethers.toUtf8Bytes("test-delivery-1"));

  beforeEach(async function () {
    [owner, driver, customer] = await ethers.getSigners();
    driverAddress = await driver.getAddress();
    customerAddress = await customer.getAddress();

    const Tracking = await ethers.getContractFactory("DeliveryTrackingSystem");
    tracking = await Tracking.deploy() as unknown as DeliveryTrackingSystem;
    await tracking.waitForDeployment();

    // Authorize driver for this delivery
    await tracking.authorizeDriver(deliveryId, driverAddress);
  });

  describe("Location Tracking (Solves Guam Container Problem)", function () {
    it("Should record location checkpoints immutably", async function () {
      const locationHash1 = ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937")); // Guam coords
      
      // Add checkpoint
      await expect(
        tracking.connect(driver).addCheckpoint(deliveryId, locationHash1, "pickup")
      ).to.emit(tracking, "LocationCheckpoint")
        .withArgs(deliveryId, locationHash1, (stamp: bigint) => stamp > 0n, "pickup");
      
      // Verify stored
      const current = await tracking.getCurrentLocation(deliveryId);
      expect(current.location).to.equal(locationHash1);
      expect(current.checkpoints).to.equal(1);
    });

    it("Should track multiple checkpoints during delivery journey", async function () {
      // Simulate delivery journey: pickup → transit → delivered
      const locations = [
        ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937")), // Pickup
        ethers.keccak256(ethers.toUtf8Bytes("13.4500,144.8000")), // In transit
        ethers.keccak256(ethers.toUtf8Bytes("13.4600,144.8100")), // Delivered
      ];

      for (let i = 0; i < locations.length; i++) {
        if (i > 0) {
          await ethers.provider.send("evm_increaseTime", [61]);
          await ethers.provider.send("evm_mine", []);
        }
        await tracking.connect(driver).addCheckpoint(
          deliveryId,
          locations[i],
          i === 0 ? "pickup" : i === locations.length - 1 ? "delivered" : "in_transit"
        );
      }

      // Verify all recorded
      const current = await tracking.getCurrentLocation(deliveryId);
      expect(current.checkpoints).to.equal(3);
      expect(current.location).to.equal(locations[2]); // Last location stored
    });

    it("Should prevent unauthorized checkpoint additions", async function () {
      const locationHash = ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937"));
      
      // Customer (not authorized) tries to add checkpoint
      await expect(
        tracking.connect(customer).addCheckpoint(deliveryId, locationHash, "fake")
      ).to.be.revertedWith("DeliveryTracking: Not authorized");
    });
  });

  describe("Proof of Delivery (RQ1: Transparency)", function () {
    it("Should store pickup proof", async function () {
      const photoHash = ethers.keccak256(ethers.toUtf8Bytes("ipfs://QmPickupPhoto123"));
      
      await expect(
        tracking.connect(driver).submitPickupProof(deliveryId, photoHash)
      ).to.emit(tracking, "ProofSubmitted")
        .withArgs(deliveryId, photoHash, "pickup", driverAddress);
      
      const current = await tracking.getCurrentLocation(deliveryId);
      expect(current.pickupProof).to.equal(photoHash);
    });

    it("Should store delivery proof", async function () {
      const photoHash = ethers.keccak256(ethers.toUtf8Bytes("ipfs://QmDeliveryPhoto456"));
      
      await expect(
        tracking.connect(driver).submitDeliveryProof(deliveryId, photoHash)
      ).to.emit(tracking, "ProofSubmitted")
        .withArgs(deliveryId, photoHash, "delivery", driverAddress);
      
      const current = await tracking.getCurrentLocation(deliveryId);
      expect(current.deliveryProof).to.equal(photoHash);
    });

    it("Should prevent duplicate proof submissions", async function () {
      const photoHash1 = ethers.keccak256(ethers.toUtf8Bytes("ipfs://First"));
      const photoHash2 = ethers.keccak256(ethers.toUtf8Bytes("ipfs://Second"));
      
      // First submission succeeds
      await tracking.connect(driver).submitPickupProof(deliveryId, photoHash1);
      
      // Second submission should fail
      await expect(
        tracking.connect(driver).submitPickupProof(deliveryId, photoHash2)
      ).to.be.revertedWith("DeliveryTracking: Pickup proof already submitted");
    });
  });

  describe("Dispute Resolution (Transparency Feature)", function () {
    it("Should allow disputes to be raised", async function () {
      const reason = "Package damaged during delivery";
      
      await expect(
        tracking.connect(driver).raiseDispute(deliveryId, reason)
      ).to.emit(tracking, "DisputeRaised")
        .withArgs(deliveryId, driverAddress, reason, (stamp: bigint) => stamp > 0n);
      
      const current = await tracking.getCurrentLocation(deliveryId);
      expect(current.disputed).to.be.true;
    });

    it("Should prevent duplicate disputes", async function () {
      await tracking.connect(driver).raiseDispute(deliveryId, "First dispute");
      
      await expect(
        tracking.connect(driver).raiseDispute(deliveryId, "Second dispute")
      ).to.be.revertedWith("DeliveryTracking: Already disputed");
    });
  });

  describe("Gas Efficiency (Thesis Performance Analysis)", function () {
    it("Should use minimal gas for checkpoint addition", async function () {
      const locationHash = ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937"));
      
      const tx = await tracking.connect(driver).addCheckpoint(deliveryId, locationHash, "pickup");
      const receipt = await tx.wait();
      
      console.log(`      Gas for addCheckpoint: ${receipt?.gasUsed}`);
      
      // Should be under 50k gas (thesis requirement)
      expect(receipt?.gasUsed).to.be.lessThan(50000);
    });
  });

  describe("Query Functions (Accessibility - RQ1)", function () {
    it("Should allow anyone to query delivery location", async function () {
      // Add some checkpoints
      const location = ethers.keccak256(ethers.toUtf8Bytes("13.4443,144.7937"));
      await tracking.connect(driver).addCheckpoint(deliveryId, location, "pickup");
      
      // Anyone can query (transparency!)
      const current = await tracking.connect(customer).getCurrentLocation(deliveryId);
      
      expect(current.location).to.equal(location);
      expect(current.checkpoints).to.equal(1);
      
      // Academic value: Public visibility solves "where is my package?" problem
    });
  });
});

