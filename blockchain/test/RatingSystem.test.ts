import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { RatingSystem } from "../typechain-types/contracts/core/RatingSystem";

describe("RatingSystem", function () {
  let ratingSystem: RatingSystem;
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

    // Deploy RatingSystem
    const RatingSystem = await ethers.getContractFactory("RatingSystem");
    ratingSystem = await RatingSystem.deploy() as unknown as RatingSystem;
    await ratingSystem.waitForDeployment();
  });

  describe("Rating Submission", function () {
    it("Should allow users to submit ratings", async function () {
      const deliveryId = 1;
      const rating = 5;
      const comment = "Great service!";

      await expect(ratingSystem.connect(user1).submitRating(deliveryId, rating, comment))
        .to.emit(ratingSystem, "RatingSubmitted")
        .withArgs(deliveryId, user1Address, rating, comment);

      const [retrievedRating, retrievedComment, reviewer] = await ratingSystem.getRating(deliveryId);
      expect(retrievedRating).to.equal(rating);
      expect(retrievedComment).to.equal(comment);
      expect(reviewer).to.equal(user1Address);
    });

    it("Should fail if rating is out of range", async function () {
      const deliveryId = 1;
      const invalidRating = 6;
      const comment = "Great service!";

      await expect(
        ratingSystem.connect(user1).submitRating(deliveryId, invalidRating, comment)
      ).to.be.revertedWith("Rating must be between 1 and 5");
    });

    it("Should fail if delivery is already rated", async function () {
      const deliveryId = 1;
      const rating = 5;
      const comment = "Great service!";

      await ratingSystem.connect(user1).submitRating(deliveryId, rating, comment);
      await expect(
        ratingSystem.connect(user2).submitRating(deliveryId, rating, comment)
      ).to.be.revertedWith("Delivery already rated");
    });
  });

  describe("Rating Retrieval", function () {
    const deliveryId = 1;
    const rating = 5;
    const comment = "Great service!";

    beforeEach(async function () {
      await ratingSystem.connect(user1).submitRating(deliveryId, rating, comment);
    });

    it("Should return correct rating data", async function () {
      const [retrievedRating, retrievedComment, reviewer] = await ratingSystem.getRating(deliveryId);
      expect(retrievedRating).to.equal(rating);
      expect(retrievedComment).to.equal(comment);
      expect(reviewer).to.equal(user1Address);
    });

    it("Should return zero for unrated delivery", async function () {
      const unratedDeliveryId = 2;
      const [retrievedRating, retrievedComment, reviewer] = await ratingSystem.getRating(unratedDeliveryId);
      expect(retrievedRating).to.equal(0);
      expect(retrievedComment).to.equal("");
      expect(reviewer).to.equal(ethers.ZeroAddress);
    });
  });

  describe("Average Rating", function () {
    it("Should calculate correct average rating", async function () {
      // Submit multiple ratings
      await ratingSystem.connect(user1).submitRating(1, 5, "Great!");
      await ratingSystem.connect(user2).submitRating(2, 4, "Good!");
      await ratingSystem.connect(user1).submitRating(3, 3, "Okay");

      const averageRating = await ratingSystem.getAverageRating();
      expect(averageRating).to.equal(4); // (5 + 4 + 3) / 3 = 4
    });

    it("Should return 0 if no ratings exist", async function () {
      const averageRating = await ratingSystem.getAverageRating();
      expect(averageRating).to.equal(0);
    });

    it("Should handle gaps in delivery IDs", async function () {
      await ratingSystem.connect(user1).submitRating(1, 5, "Great!");
      await ratingSystem.connect(user2).submitRating(3, 3, "Okay");
      await ratingSystem.connect(user1).submitRating(5, 4, "Good!");

      const averageRating = await ratingSystem.getAverageRating();
      expect(averageRating).to.equal(4); // (5 + 3 + 4) / 3 = 4
    });
  });

  describe("Rating Count", function () {
    it("Should track correct number of ratings", async function () {
      // Submit multiple ratings
      await ratingSystem.connect(user1).submitRating(1, 5, "Great!");
      await ratingSystem.connect(user2).submitRating(2, 4, "Good!");
      await ratingSystem.connect(user1).submitRating(3, 3, "Okay");

      const ratingCount = await ratingSystem.getRatingCount();
      expect(ratingCount).to.equal(3);
    });

    it("Should return 0 if no ratings exist", async function () {
      const ratingCount = await ratingSystem.getRatingCount();
      expect(ratingCount).to.equal(0);
    });
  });
}); 