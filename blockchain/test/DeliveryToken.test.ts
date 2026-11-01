import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";

describe("DeliveryToken", function () {
  let deliveryToken: DeliveryToken;
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

    // Deploy DeliveryToken
    const DeliveryToken = await ethers.getContractFactory("DeliveryToken");
    deliveryToken = await DeliveryToken.deploy() as unknown as DeliveryToken;
    await deliveryToken.waitForDeployment();
  });

  describe("Token Properties", function () {
    it("Should have correct name and symbol", async function () {
      expect(await deliveryToken.name()).to.equal("Reliable Logistics Exchange");
      expect(await deliveryToken.symbol()).to.equal("RLE");
    });

    it("Should have correct decimals", async function () {
      expect(await deliveryToken.decimals()).to.equal(18);
    });
  });

  describe("Minting", function () {
    it("Should allow owner to mint tokens", async function () {
      const amount = ethers.parseEther("100");
      await deliveryToken.mint(user1Address, amount);
      expect(await deliveryToken.balanceOf(user1Address)).to.equal(amount);
    });

    it("Should fail if non-owner tries to mint", async function () {
      const amount = ethers.parseEther("100");
      await expect(
        deliveryToken.connect(user1).mint(user2Address, amount)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Transfers", function () {
    const initialAmount = ethers.parseEther("1000");

    beforeEach(async function () {
      // Mint tokens to user1
      await deliveryToken.mint(user1Address, initialAmount);
    });

    it("Should allow users to transfer tokens", async function () {
      const transferAmount = ethers.parseEther("100");
      await deliveryToken.connect(user1).transfer(user2Address, transferAmount);
      
      expect(await deliveryToken.balanceOf(user1Address)).to.equal(
        initialAmount - transferAmount
      );
      expect(await deliveryToken.balanceOf(user2Address)).to.equal(transferAmount);
    });

    it("Should fail if user tries to transfer more than balance", async function () {
      const transferAmount = ethers.parseEther("2000");
      await expect(
        deliveryToken.connect(user1).transfer(user2Address, transferAmount)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });

  describe("Allowances", function () {
    const initialAmount = ethers.parseEther("1000");
    const approveAmount = ethers.parseEther("100");

    beforeEach(async function () {
      // Mint tokens to user1
      await deliveryToken.mint(user1Address, initialAmount);
    });

    it("Should allow users to approve spending", async function () {
      await deliveryToken.connect(user1).approve(user2Address, approveAmount);
      expect(await deliveryToken.allowance(user1Address, user2Address)).to.equal(
        approveAmount
      );
    });

    it("Should allow approved users to transfer tokens", async function () {
      await deliveryToken.connect(user1).approve(user2Address, approveAmount);
      await deliveryToken.connect(user2).transferFrom(user1Address, user2Address, approveAmount);
      
      expect(await deliveryToken.balanceOf(user1Address)).to.equal(
        initialAmount - approveAmount
      );
      expect(await deliveryToken.balanceOf(user2Address)).to.equal(approveAmount);
    });
  });
}); 