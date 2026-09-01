import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliveryNFT } from "../typechain-types/contracts/tokens/DeliveryNFT";

/**
 * ARCHIVED: DeliveryNFT test file
 * This test is archived because DeliveryNFT contract is not used in the current MVP.
 * Kept for reference and potential future implementation.
 */
describe("DeliveryNFT", function () {
  let deliveryNFT: DeliveryNFT;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    const DeliveryNFT = await ethers.getContractFactory("DeliveryNFT");
    deliveryNFT = await DeliveryNFT.deploy();
    await deliveryNFT.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await deliveryNFT.owner()).to.equal(await owner.getAddress());
    });

    it("Should have correct token IDs", async function () {
      expect(await deliveryNFT.DELIVERY_RECEIPT()).to.equal(1);
      expect(await deliveryNFT.ACHIEVEMENT_BADGE()).to.equal(2);
    });
  });

  describe("Delivery Receipt Minting", function () {
    it("Should mint delivery receipt NFT", async function () {
      const user1Address = await user1.getAddress();
      const deliveryId = 123;
      const metadataURI = "https://example.com/metadata/123";

      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, metadataURI);

      expect(await deliveryNFT.balanceOf(user1Address, 1)).to.equal(1);
      expect(await deliveryNFT.tokenURI(deliveryId)).to.equal(metadataURI);
    });

    it("Should emit DeliveryReceiptMinted event", async function () {
      const user1Address = await user1.getAddress();
      const deliveryId = 123;
      const metadataURI = "https://example.com/metadata/123";

      await expect(deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, metadataURI))
        .to.emit(deliveryNFT, "DeliveryReceiptMinted")
        .withArgs(user1Address, deliveryId, metadataURI);
    });
  });

  describe("Achievement Badge Minting", function () {
    it("Should mint achievement badge NFT", async function () {
      const user1Address = await user1.getAddress();
      const badgeType = 456;
      const metadataURI = "https://example.com/badge/456";

      await deliveryNFT.mintAchievementBadge(user1Address, badgeType, metadataURI);

      expect(await deliveryNFT.balanceOf(user1Address, 2)).to.equal(1);
      expect(await deliveryNFT.tokenURI(badgeType)).to.equal(metadataURI);
    });

    it("Should emit AchievementBadgeMinted event", async function () {
      const user1Address = await user1.getAddress();
      const badgeType = 456;
      const metadataURI = "https://example.com/badge/456";

      await expect(deliveryNFT.mintAchievementBadge(user1Address, badgeType, metadataURI))
        .to.emit(deliveryNFT, "AchievementBadgeMinted")
        .withArgs(user1Address, badgeType, metadataURI);
    });
  });

  describe("Metadata URI Management", function () {
    it("Should update token URI", async function () {
      const tokenId = 789;
      const newURI = "https://example.com/updated/789";

      await deliveryNFT.setTokenURI(tokenId, newURI);
      expect(await deliveryNFT.tokenURI(tokenId)).to.equal(newURI);
    });

    it("Should emit MetadataURIUpdated event", async function () {
      const tokenId = 789;
      const newURI = "https://example.com/updated/789";

      await expect(deliveryNFT.setTokenURI(tokenId, newURI))
        .to.emit(deliveryNFT, "MetadataURIUpdated")
        .withArgs(tokenId, newURI);
    });
  });

  describe("Access Control", function () {
    it("Should only allow owner to mint", async function () {
      const user1Address = await user1.getAddress();
      const deliveryId = 123;
      const metadataURI = "https://example.com/metadata/123";

      await expect(
        deliveryNFT.connect(user1).mintDeliveryReceipt(user1Address, deliveryId, metadataURI)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should only allow owner to update URI", async function () {
      const tokenId = 789;
      const newURI = "https://example.com/updated/789";

      await expect(
        deliveryNFT.connect(user1).setTokenURI(tokenId, newURI)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});









