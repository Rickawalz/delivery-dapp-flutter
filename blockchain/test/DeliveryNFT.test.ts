import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliveryNFT } from "../typechain-types/contracts/tokens/DeliveryNFT";

describe("DeliveryNFT", function () {
  let deliveryNFT: DeliveryNFT;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;
  let ownerAddress: string;
  let user1Address: string;
  let user2Address: string;

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();

    // Deploy DeliveryNFT
    const DeliveryNFT = await ethers.getContractFactory("DeliveryNFT");
    deliveryNFT = await DeliveryNFT.deploy() as unknown as DeliveryNFT;
    await deliveryNFT.waitForDeployment();
  });

  describe("NFT Properties", function () {
    it("Should have correct token IDs", async function () {
      expect(await deliveryNFT.DELIVERY_RECEIPT()).to.equal(1);
      expect(await deliveryNFT.ACHIEVEMENT_BADGE()).to.equal(2);
    });
  });

  describe("Minting", function () {
    it("Should allow owner to mint delivery receipt NFT", async function () {
      const deliveryId = 1;
      const tokenURI = "ipfs://QmTest";
      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, tokenURI);
      
      expect(await deliveryNFT.balanceOf(user1Address, 1)).to.equal(1);
      expect(await deliveryNFT.tokenURI(deliveryId)).to.equal(tokenURI);
    });

    it("Should allow owner to mint achievement badge NFT", async function () {
      const badgeType = 1;
      const tokenURI = "ipfs://QmBadge";
      await deliveryNFT.mintAchievementBadge(user1Address, badgeType, tokenURI);
      
      expect(await deliveryNFT.balanceOf(user1Address, 2)).to.equal(1);
      expect(await deliveryNFT.tokenURI(badgeType)).to.equal(tokenURI);
    });

    it("Should fail if non-owner tries to mint", async function () {
      const deliveryId = 1;
      const tokenURI = "ipfs://QmTest";
      await expect(
        deliveryNFT.connect(user1).mintDeliveryReceipt(user2Address, deliveryId, tokenURI)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Transfers", function () {
    const deliveryId = 1;
    const tokenURI = "ipfs://QmTest";

    beforeEach(async function () {
      // Mint NFT to user1
      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, tokenURI);
    });

    it("Should allow users to transfer NFT", async function () {
      await deliveryNFT.connect(user1).safeTransferFrom(user1Address, user2Address, 1, 1, "0x");
      expect(await deliveryNFT.balanceOf(user1Address, 1)).to.equal(0);
      expect(await deliveryNFT.balanceOf(user2Address, 1)).to.equal(1);
    });

    it("Should fail if user tries to transfer NFT they don't own", async function () {
      await expect(
        deliveryNFT.connect(user2).safeTransferFrom(user1Address, user2Address, 1, 1, "0x")
      ).to.be.revertedWith("ERC1155: caller is not token owner or approved");
    });
  });

  describe("Approvals", function () {
    const deliveryId = 1;
    const tokenURI = "ipfs://QmTest";

    beforeEach(async function () {
      // Mint NFT to user1
      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, tokenURI);
    });

    it("Should allow users to approve others to transfer NFT", async function () {
      await deliveryNFT.connect(user1).setApprovalForAll(user2Address, true);
      expect(await deliveryNFT.isApprovedForAll(user1Address, user2Address)).to.equal(true);
    });

    it("Should allow approved users to transfer NFT", async function () {
      await deliveryNFT.connect(user1).setApprovalForAll(user2Address, true);
      await deliveryNFT.connect(user2).safeTransferFrom(user1Address, user2Address, 1, 1, "0x");
      expect(await deliveryNFT.balanceOf(user2Address, 1)).to.equal(1);
    });
  });

  describe("Metadata", function () {
    it("Should allow owner to update token URI", async function () {
      const deliveryId = 1;
      const initialURI = "ipfs://QmTest";
      const newURI = "ipfs://QmNewTest";
      
      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, initialURI);
      await deliveryNFT.setTokenURI(deliveryId, newURI);
      
      expect(await deliveryNFT.tokenURI(deliveryId)).to.equal(newURI);
    });

    it("Should fail if non-owner tries to update token URI", async function () {
      const deliveryId = 1;
      const initialURI = "ipfs://QmTest";
      const newURI = "ipfs://QmNewTest";
      
      await deliveryNFT.mintDeliveryReceipt(user1Address, deliveryId, initialURI);
      await expect(
        deliveryNFT.connect(user1).setTokenURI(deliveryId, newURI)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
}); 