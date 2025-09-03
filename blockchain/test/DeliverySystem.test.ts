import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliverySystem } from "../typechain-types/contracts/core/DeliverySystem";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

describe("DeliverySystem", function () {
  let deliverySystem: DeliverySystem;
  let deliveryToken: DeliveryToken;
  let owner: Signer;
  let sender: Signer;
  let receiver: Signer;
  let ownerAddress: string;
  let senderAddress: string;
  let receiverAddress: string;

  beforeEach(async function () {
    // Get signers
    [owner, sender, receiver] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    senderAddress = await sender.getAddress();
    receiverAddress = await receiver.getAddress();

    // Deploy DeliveryToken
    const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
    deliveryToken = await DeliveryToken.deploy() as unknown as DeliveryToken;
    await deliveryToken.waitForDeployment();

    // Deploy DeliverySystem
    const DeliverySystem = await ethers.getContractFactory("DeliverySystem");
    deliverySystem = await DeliverySystem.deploy(await deliveryToken.getAddress()) as unknown as DeliverySystem;
    await deliverySystem.waitForDeployment();

    // Mint tokens to sender
    await deliveryToken.mint(senderAddress, ethers.parseEther("1000"));
  });

  describe("Delivery Creation", function () {
    it("Should create a new delivery", async function () {
      const amount = ethers.parseEther("1");

      // Approve tokens
      await deliveryToken.connect(sender).approve(await deliverySystem.getAddress(), amount);

      // Create delivery and get the transaction
      const tx = await deliverySystem.connect(sender).createDelivery(receiverAddress, amount);
      const receipt = await tx.wait();

      // Get the DeliveryCreated event
      const iface = deliverySystem.interface;
      const event = receipt?.logs.find(
        log => log.topics[0] === iface.getEvent("DeliveryCreated")?.topicHash
      );

      if (!event) {
        throw new Error("DeliveryCreated event not found");
      }

      const parsedEvent = iface.parseLog({
        topics: event.topics,
        data: event.data
      });

      const deliveryId = parsedEvent?.args[0];

      // Check delivery data
      const delivery = await deliverySystem.getDelivery(deliveryId);
      expect(delivery[0]).to.equal(senderAddress); // sender
      expect(delivery[1]).to.equal(receiverAddress); // receiver
      expect(delivery[2]).to.equal(amount); // amount
      expect(delivery[3]).to.equal(false); // completed
      expect(delivery[4]).to.be.gt(0); // timestamp
    });

    it("Should fail if amount is zero", async function () {
      await expect(
        deliverySystem.connect(sender).createDelivery(receiverAddress, 0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });
  });

  describe("Delivery Completion", function () {
    let deliveryId: string;
    const amount = ethers.parseEther("1");

    beforeEach(async function () {
      // Approve tokens
      await deliveryToken.connect(sender).approve(await deliverySystem.getAddress(), amount);

      // Create delivery and get the transaction
      const tx = await deliverySystem.connect(sender).createDelivery(receiverAddress, amount);
      const receipt = await tx.wait();

      // Get the DeliveryCreated event
      const iface = deliverySystem.interface;
      const event = receipt?.logs.find(
        log => log.topics[0] === iface.getEvent("DeliveryCreated")?.topicHash
      );

      if (!event) {
        throw new Error("DeliveryCreated event not found");
      }

      const parsedEvent = iface.parseLog({
        topics: event.topics,
        data: event.data
      });

      deliveryId = parsedEvent?.args[0];

      // Verify the delivery exists
      const delivery = await deliverySystem.getDelivery(deliveryId);
      expect(delivery[0]).to.equal(senderAddress); // sender
      expect(delivery[1]).to.equal(receiverAddress); // receiver
      expect(delivery[2]).to.equal(amount); // amount
      expect(delivery[3]).to.equal(false); // completed
    });

    it("Should allow receiver to complete delivery", async function () {
      await expect(deliverySystem.connect(receiver).completeDelivery(deliveryId))
        .to.emit(deliverySystem, "DeliveryCompleted")
        .withArgs(deliveryId);
      
      const delivery = await deliverySystem.getDelivery(deliveryId);
      expect(delivery[3]).to.equal(true); // completed
    });

    it("Should fail if non-receiver tries to complete delivery", async function () {
      await expect(
        deliverySystem.connect(sender).completeDelivery(deliveryId)
      ).to.be.revertedWith("Only receiver can complete delivery");
    });
  });
}); 