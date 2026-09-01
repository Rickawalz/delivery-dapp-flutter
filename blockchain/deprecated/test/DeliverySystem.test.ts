import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliverySystem } from "../typechain-types/contracts/core/DeliverySystem";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

/**
 * ARCHIVED: Legacy DeliverySystem test file
 * This test is archived because the old DeliverySystem contract was replaced by SimpleDeliverySystem.
 * Kept for reference and potential future implementation.
 */
describe("DeliverySystem", function () {
  let deliverySystem: DeliverySystem;
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

    // Deploy DeliverySystem
    const DeliverySystem = await ethers.getContractFactory("DeliverySystem");
    deliverySystem = await DeliverySystem.deploy(await deliveryToken.getAddress());
    await deliverySystem.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right token address", async function () {
      expect(await deliverySystem.deliveryToken()).to.equal(await deliveryToken.getAddress());
    });

    it("Should set the right owner", async function () {
      expect(await deliverySystem.owner()).to.equal(await owner.getAddress());
    });
  });

  describe("Delivery Creation", function () {
    it("Should create a delivery", async function () {
      const user1Address = await user1.getAddress();
      const user2Address = await user2.getAddress();
      const amount = ethers.parseEther("100");

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, amount);

      // Approve delivery system to spend tokens
      await deliveryToken.connect(user1).approve(await deliverySystem.getAddress(), amount);

      // Create delivery
      await expect(deliverySystem.connect(user1).createDelivery(user2Address, amount))
        .to.emit(deliverySystem, "DeliveryCreated");
    });

    it("Should fail with invalid receiver address", async function () {
      const amount = ethers.parseEther("100");
      const user1Address = await user1.getAddress();

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, amount);

      // Approve delivery system to spend tokens
      await deliveryToken.connect(user1).approve(await deliverySystem.getAddress(), amount);

      await expect(
        deliverySystem.connect(user1).createDelivery(ethers.ZeroAddress, amount)
      ).to.be.revertedWith("Invalid receiver address");
    });

    it("Should fail with zero amount", async function () {
      const user2Address = await user2.getAddress();

      await expect(
        deliverySystem.connect(user1).createDelivery(user2Address, 0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });
  });

  describe("Delivery Completion", function () {
    beforeEach(async function () {
      const user1Address = await user1.getAddress();
      const user2Address = await user2.getAddress();
      const amount = ethers.parseEther("100");

      // Mint tokens to user1
      await deliveryToken.mint(user1Address, amount);

      // Approve delivery system to spend tokens
      await deliveryToken.connect(user1).approve(await deliverySystem.getAddress(), amount);

      // Create delivery
      await deliverySystem.connect(user1).createDelivery(user2Address, amount);
    });

    it("Should complete a delivery", async function () {
      const deliveryId = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "address", "uint256", "uint256"],
          [await user1.getAddress(), await user2.getAddress(), ethers.parseEther("100"), 0]
        )
      );

      await expect(deliverySystem.completeDelivery(deliveryId))
        .to.emit(deliverySystem, "DeliveryCompleted");
    });
  });
});









