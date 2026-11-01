import { expect } from "chai";
import { ethers } from "hardhat";
import { mine, time } from "@nomicfoundation/hardhat-network-helpers";
import { Signer } from "ethers";
import { DeliveryToken } from "../typechain-types/contracts/tokens/DeliveryToken";
import { BalancedRewardSystem } from "../typechain-types/contracts/core/BalancedRewardSystem";
import { DeliveryTrackingSystem } from "../typechain-types/contracts/core/DeliveryTrackingSystem";
import { RatingSystem } from "../typechain-types/contracts/core/RatingSystem";
import { SimpleDeliverySystem } from "../typechain-types/contracts/core/SimpleDeliverySystem";
import { TestDecentralizationPhase } from "../typechain-types/contracts/test/TestDecentralizationPhase";
import { RLEGovernor } from "../typechain-types/contracts/governance/RLEGovernor";
import { TimelockController } from "../typechain-types/@openzeppelin/contracts/governance/TimelockController";

const DISTANCE_METERS = 1500;
const PAYMENT_CENTS = 200;
const TIMELOCK_DELAY = 60 * 60;
const ONE_DAY = 24 * 60 * 60;
const PHASE_HYBRID = 1n;
const PHASE_FULL_DAO = 2n;

describe("Progressive decentralization", function () {
  let founder: Signer;
  let council: Signer;
  let driverA: Signer;
  let driverB: Signer;
  let driverC: Signer;
  let customer: Signer;
  let stranger: Signer;
  let founderAddress: string;
  let councilAddress: string;
  let customerAddress: string;

  let token: DeliveryToken;
  let timelock: TimelockController;
  let governor: RLEGovernor;
  let tracking: DeliveryTrackingSystem;
  let rating: RatingSystem;
  let rewards: BalancedRewardSystem;
  let phase: TestDecentralizationPhase;
  let delivery: SimpleDeliverySystem;

  let deliveryNonce = 0;

  async function deploySystem() {
    [founder, council, driverA, driverB, driverC, customer, stranger] = await ethers.getSigners();
    founderAddress = await founder.getAddress();
    councilAddress = await council.getAddress();
    customerAddress = await customer.getAddress();

    const Token = await ethers.getContractFactory("DeliveryToken");
    token = (await Token.deploy()) as unknown as DeliveryToken;
    await token.waitForDeployment();

    const Timelock = await ethers.getContractFactory("TimelockController");
    timelock = (await Timelock.deploy(
      TIMELOCK_DELAY,
      [],
      [ethers.ZeroAddress],
      founderAddress
    )) as unknown as TimelockController;
    await timelock.waitForDeployment();

    const Governor = await ethers.getContractFactory("RLEGovernor");
    governor = (await Governor.deploy(
      await token.getAddress(),
      await timelock.getAddress(),
      1,
      5,
      0
    )) as unknown as RLEGovernor;
    await governor.waitForDeployment();

    const proposerRole = await timelock.PROPOSER_ROLE();
    const cancellerRole = await timelock.CANCELLER_ROLE();
    const adminRole = await timelock.TIMELOCK_ADMIN_ROLE();
    await timelock.grantRole(proposerRole, await governor.getAddress());
    await timelock.grantRole(cancellerRole, await governor.getAddress());
    await timelock.renounceRole(adminRole, founderAddress);

    const Tracking = await ethers.getContractFactory("DeliveryTrackingSystem");
    tracking = (await Tracking.deploy()) as unknown as DeliveryTrackingSystem;
    await tracking.waitForDeployment();

    const Rating = await ethers.getContractFactory("RatingSystem");
    rating = (await Rating.deploy()) as unknown as RatingSystem;
    await rating.waitForDeployment();

    const Rewards = await ethers.getContractFactory("BalancedRewardSystem");
    rewards = (await Rewards.deploy(await token.getAddress())) as unknown as BalancedRewardSystem;
    await rewards.waitForDeployment();

    const Phase = await ethers.getContractFactory("TestDecentralizationPhase");
    phase = (await Phase.deploy(
      councilAddress,
      await timelock.getAddress()
    )) as unknown as TestDecentralizationPhase;
    await phase.waitForDeployment();

    const Delivery = await ethers.getContractFactory("SimpleDeliverySystem");
    delivery = (await Delivery.deploy(
      await rewards.getAddress(),
      await tracking.getAddress(),
      await rating.getAddress(),
      await phase.getAddress()
    )) as unknown as SimpleDeliverySystem;
    await delivery.waitForDeployment();

    const voterAddress = await driverA.getAddress();
    await token.mint(voterAddress, ethers.parseEther("1000000"));
    await token.connect(driverA).delegate(voterAddress);

    await token.transferOwnership(await rewards.getAddress());
    await rewards.transferOwnership(await delivery.getAddress());
    await tracking.transferOwnership(await delivery.getAddress());
    await rating.transferOwnership(await delivery.getAddress());
    await phase.transferOwnership(await delivery.getAddress());
  }

  function nextDeliveryId(label: string) {
    deliveryNonce += 1;
    return ethers.id(`${label}-${deliveryNonce}`);
  }

  async function completeDelivery(driver: Signer, label: string) {
    const deliveryId = nextDeliveryId(label);
    const driverAddress = await driver.getAddress();
    await delivery.connect(customer).createDelivery(
      deliveryId,
      driverAddress,
      DISTANCE_METERS,
      PAYMENT_CENTS
    );
    await time.increase(10 * 60);
    const tx = await delivery.connect(customer).completeDelivery(deliveryId, 5);
    const receipt = await tx.wait();
    return { deliveryId, receipt };
  }

  async function advanceToHybrid() {
    await time.increase(ONE_DAY);
    await completeDelivery(driverA, "hybrid-1");
    await completeDelivery(driverB, "hybrid-2");
    const third = await completeDelivery(driverA, "hybrid-3");
    return third.receipt;
  }

  async function advanceToFullDAO() {
    const hybridReceipt = await advanceToHybrid();
    await completeDelivery(driverA, "dao-4");
    await completeDelivery(driverB, "dao-5");
    const sixth = await completeDelivery(driverC, "dao-6");
    return { hybridReceipt, fullReceipt: sixth.receipt };
  }

  describe("Controllers", function () {
    beforeEach(async function () {
      await deploySystem();
    });

    it("uses the founder during Bootstrap", async function () {
      expect(await phase.currentController()).to.equal(founderAddress);
      expect(await phase.currentPhase()).to.equal(0);
    });

    it("rejects a direct phase call from the founder", async function () {
      await expect(
        phase.connect(founder).recordDelivery(await driverA.getAddress(), customerAddress, PAYMENT_CENTS)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        phase.connect(founder).recordIncident("founder bypass")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("rejects reward-rate governance during Bootstrap and allows the emergency override", async function () {
      await expect(
        delivery.connect(founder).setRewardTokenRate(ethers.parseEther("3"))
      ).to.be.revertedWith("DeliverySystem: Not during Bootstrap");

      await delivery.connect(founder).emergencyAdjustRewardRate(ethers.parseEther("2"));
      expect(await rewards.currentTokenRate()).to.equal(ethers.parseEther("2"));
    });

    it("blocks an outside account from submitting or updating a rating", async function () {
      await expect(
        rating.connect(stranger).submitRating(1, 5, "front run")
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        rating.connect(stranger).updateRating(1, 4, "front run")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Phase advance", function () {
    beforeEach(async function () {
      await deploySystem();
    });

    it("reverts advancePhase before the milestones are met", async function () {
      await expect(
        phase.connect(stranger).advancePhase()
      ).to.be.revertedWith("DecentralizationPhase: Milestones not met");
    });

    it("advances to Hybrid in the completeDelivery that meets the milestones", async function () {
      const receipt = await advanceToHybrid();
      console.log(`       Hybrid advance gasUsed: ${receipt?.gasUsed}`);

      const decoded = (receipt?.logs ?? []).flatMap((log) => {
        try {
          const parsed = phase.interface.parseLog(log);
          return parsed ? [parsed] : [];
        } catch {
          return [];
        }
      });
      const advanced = decoded.find((log) => log.name === "PhaseAdvanced");
      const changed = decoded.find((log) => log.name === "ControllerChanged");
      expect(advanced).to.not.equal(undefined);
      expect(changed).to.not.equal(undefined);
      expect(advanced?.args.newPhase).to.equal(PHASE_HYBRID);
      expect(advanced?.args.deliveries).to.equal(3);
      expect(advanced?.args.drivers).to.equal(2);
      expect(changed?.args.previous).to.equal(founderAddress);
      expect(changed?.args.next).to.equal(councilAddress);
      expect(changed?.args.phase).to.equal(PHASE_HYBRID);

      expect(await phase.currentPhase()).to.equal(PHASE_HYBRID);
      expect(await phase.currentController()).to.equal(councilAddress);
    });

    it("lets a random account advance once the time milestone is met", async function () {
      await completeDelivery(driverA, "fallback-1");
      await completeDelivery(driverB, "fallback-2");
      await completeDelivery(driverA, "fallback-3");

      expect(await phase.currentPhase()).to.equal(0);
      await expect(
        phase.connect(stranger).advancePhase()
      ).to.be.revertedWith("DecentralizationPhase: Milestones not met");

      await time.increase(ONE_DAY);
      await phase.connect(stranger).advancePhase();

      expect(await phase.currentPhase()).to.equal(PHASE_HYBRID);
      expect(await phase.currentController()).to.equal(councilAddress);
    });
  });

  describe("After Hybrid", function () {
    beforeEach(async function () {
      await deploySystem();
      await advanceToHybrid();
    });

    it("removes the founder's controller powers", async function () {
      const openId = nextDeliveryId("founder-cancel");
      await delivery.connect(customer).createDelivery(
        openId,
        await driverA.getAddress(),
        DISTANCE_METERS,
        PAYMENT_CENTS
      );

      await expect(
        delivery.connect(founder).recordIncident("too late")
      ).to.be.revertedWith("DeliverySystem: Not controller");
      await expect(
        delivery.connect(founder).resolveDispute(openId)
      ).to.be.revertedWith("DeliverySystem: Not controller");
      await expect(
        delivery.connect(founder).setPlatformFeePercent(1)
      ).to.be.revertedWith("DeliverySystem: Not controller");
      await expect(
        delivery.connect(founder).emergencyAdjustRewardRate(ethers.parseEther("2"))
      ).to.be.revertedWith("DeliverySystem: Not controller");
      await expect(
        delivery.connect(founder).cancelDelivery(openId, "founder")
      ).to.be.revertedWith("DeliverySystem: Not authorized");
    });

    it("requires the customer to complete a delivery", async function () {
      const deliveryId = nextDeliveryId("hybrid-customer");
      await delivery.connect(customer).createDelivery(
        deliveryId,
        await driverB.getAddress(),
        DISTANCE_METERS,
        PAYMENT_CENTS
      );

      await expect(
        delivery.connect(stranger).completeDelivery(deliveryId, 5)
      ).to.be.revertedWith("DeliverySystem: Customer confirmation required");

      await time.increase(10 * 60);
      await delivery.connect(customer).completeDelivery(deliveryId, 5);
      expect((await delivery.getDelivery(deliveryId)).status).to.equal(2);
    });

    it("blocks completion while a delivery is disputed", async function () {
      const deliveryId = nextDeliveryId("hybrid-dispute");
      await delivery.connect(customer).createDelivery(
        deliveryId,
        await driverA.getAddress(),
        DISTANCE_METERS,
        PAYMENT_CENTS
      );
      await tracking.connect(customer).raiseDispute(deliveryId, "damaged");

      await expect(
        delivery.connect(customer).completeDelivery(deliveryId, 4)
      ).to.be.revertedWith("DeliverySystem: Delivery is disputed");

      await delivery.connect(council).resolveDispute(deliveryId);
      expect(await tracking.isDisputed(deliveryId)).to.equal(false);

      await time.increase(10 * 60);
      await delivery.connect(customer).completeDelivery(deliveryId, 4);
      expect((await delivery.getDelivery(deliveryId)).status).to.equal(2);
    });

    it("allows the governance rate only after Bootstrap", async function () {
      await expect(
        delivery.connect(council).emergencyAdjustRewardRate(ethers.parseEther("4"))
      ).to.be.revertedWith("DeliverySystem: Bootstrap only");

      await delivery.connect(council).setRewardTokenRate(ethers.parseEther("3"));
      expect(await rewards.currentTokenRate()).to.equal(ethers.parseEther("3"));
    });
  });

  describe("Incidents", function () {
    beforeEach(async function () {
      await deploySystem();
    });

    it("enforces the cooldown and cap, then resets the counter on advance", async function () {
      await delivery.connect(founder).recordIncident("one");
      expect(await phase.incidentsThisPhase()).to.equal(1);

      await expect(
        delivery.connect(founder).recordIncident("too soon")
      ).to.be.revertedWith("DecentralizationPhase: Incident cooldown active");

      await time.increase(7 * ONE_DAY);
      await delivery.connect(founder).recordIncident("two");
      await time.increase(7 * ONE_DAY);
      await delivery.connect(founder).recordIncident("three");
      expect(await phase.incidentsThisPhase()).to.equal(3);

      await expect(
        delivery.connect(founder).recordIncident("still cooling")
      ).to.be.revertedWith("DecentralizationPhase: Incident cooldown active");

      await time.increase(7 * ONE_DAY);
      await expect(
        delivery.connect(founder).recordIncident("fourth")
      ).to.be.revertedWith("DecentralizationPhase: Incident cap reached");

      await completeDelivery(driverA, "incident-1");
      await completeDelivery(driverB, "incident-2");
      await completeDelivery(driverA, "incident-3");

      expect(await phase.currentPhase()).to.equal(PHASE_HYBRID);
      expect(await phase.incidentsThisPhase()).to.equal(0);

      await delivery.connect(council).recordIncident("new phase");
      expect(await phase.incidentsThisPhase()).to.equal(1);
      expect(await phase.currentPhase()).to.equal(PHASE_HYBRID);
    });
  });

  describe("FullDAO", function () {
    let loggedAdvanceGas = false;

    beforeEach(async function () {
      await deploySystem();
      const receipts = await advanceToFullDAO();
      if (!loggedAdvanceGas) {
        console.log(`       Hybrid advance gasUsed: ${receipts.hybridReceipt?.gasUsed}`);
        console.log(`       FullDAO advance gasUsed: ${receipts.fullReceipt?.gasUsed}`);
        loggedAdvanceGas = true;
      }
    });

    it("uses the timelock and does not move backward", async function () {
      expect(await phase.currentPhase()).to.equal(PHASE_FULL_DAO);
      expect(await phase.currentController()).to.equal(await timelock.getAddress());

      await expect(
        phase.connect(stranger).advancePhase()
      ).to.be.revertedWith("DecentralizationPhase: Already at FullDAO");

      await completeDelivery(driverA, "after-dao");
      expect(await phase.currentPhase()).to.equal(PHASE_FULL_DAO);
      expect(await phase.currentController()).to.equal(await timelock.getAddress());
    });

    it("requires the customer to complete a delivery", async function () {
      const deliveryId = nextDeliveryId("dao-customer");
      await delivery.connect(customer).createDelivery(
        deliveryId,
        await driverC.getAddress(),
        DISTANCE_METERS,
        PAYMENT_CENTS
      );

      await expect(
        delivery.connect(council).completeDelivery(deliveryId, 5)
      ).to.be.revertedWith("DeliverySystem: Customer confirmation required");

      await time.increase(10 * 60);
      await delivery.connect(customer).completeDelivery(deliveryId, 5);
      expect((await delivery.getDelivery(deliveryId)).status).to.equal(2);
    });

    it("changes the platform fee through a governor proposal", async function () {
      const targets = [await delivery.getAddress()];
      const values = [0];
      const calldatas = [delivery.interface.encodeFunctionData("setPlatformFeePercent", [1])];
      const description = "Set platform fee to 1 percent";
      const descriptionHash = ethers.id(description);

      await governor.connect(driverA).propose(targets, values, calldatas, description);
      const proposalId = await governor.hashProposal(targets, values, calldatas, descriptionHash);

      await mine(2);
      await governor.connect(driverA).castVote(proposalId, 1);
      await mine(10);

      expect(await governor.state(proposalId)).to.equal(4n);

      await governor.queue(targets, values, calldatas, descriptionHash);
      await time.increase(TIMELOCK_DELAY + 1);
      await governor.execute(targets, values, calldatas, descriptionHash);

      expect((await delivery.getPlatformStats()).feePercent).to.equal(1);
      await expect(
        delivery.connect(council).setPlatformFeePercent(2)
      ).to.be.revertedWith("DeliverySystem: Not controller");
    });
  });
});
