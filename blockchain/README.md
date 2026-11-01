# Reliable Logistics Exchange contracts

Hardhat project for the RLE delivery contracts. Solidity `^0.8.19`, OpenZeppelin Contracts 4.9, ethers v6.

The live path is `DeliveryToken`, `BalancedRewardSystem`, `DeliveryTrackingSystem`, `RatingSystem`, `SimpleDeliverySystem`, `DecentralizationPhase`, `RLEGovernor`, and OpenZeppelin's `TimelockController`. `SimpleDeliverySystem` is not `Ownable`. It calls the other contracts, and those contracts are owned by it. The token is owned by `BalancedRewardSystem`.

## Local demo

```shell
cd blockchain
npx hardhat node --hostname 0.0.0.0
npx hardhat run scripts/deploy-thesis.ts --network localhost
```

Then, from `app`:

```shell
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

On the local Hardhat node, account #0 is the deployer and the Bootstrap founder. Account #1 is the hybrid council when `HYBRID_COUNCIL_ADDRESS` is not set. Further accounts can be used as customers and drivers.

`deploy-thesis.ts` writes the detected LAN address to `app/assets/config/dev_host.json`. That file is git-ignored. When it is absent, the app uses `10.0.2.2`, which is the Android emulator's route to the host. The script also copies the `SimpleDeliverySystem` ABI into `app/assets/abi/SimpleDeliverySystem.json`.

## Controllers

`DecentralizationPhase` has three controllers. Only one is active, and `currentController()` returns it:

| Phase | Active controller | When it becomes active |
|---|---|---|
| Bootstrap | Founder, the address that deployed `DecentralizationPhase` | Deployment. This is the starting phase. |
| Hybrid | `hybridCouncil`, set in the constructor | After 10,000 deliveries, 100 drivers, 180 days, and 30 days without an incident. |
| FullDAO | `daoTimelock`, the `TimelockController` | After 1,000,000 deliveries, 10,000 drivers, $10,000,000 GMV, and 90 days without an incident. |

The `Ownable` owner of the phase, reward, tracking, and rating contracts is `SimpleDeliverySystem`. That owner is not the phase controller. Controller calls go through `SimpleDeliverySystem`, which checks `currentController()`.

## Phase advancement

Advancement is automatic and permissionless. `recordDelivery`, which `SimpleDeliverySystem` calls at the end of `completeDelivery`, tries to advance. The `completeDelivery` that meets the next phase's milestones moves the phase in that same transaction and emits `PhaseAdvanced` and `ControllerChanged`.

Anyone can also call `advancePhase()` once those milestones are already met. Before they are met it reverts with `DecentralizationPhase: Milestones not met`. At FullDAO it reverts with `DecentralizationPhase: Already at FullDAO`. A call moves at most one phase, and the phase never moves backward. The founder cannot block, delay, or skip a handover.

## Incidents

`recordIncident` on the phase contract is owner-only, so it is reached through `SimpleDeliverySystem.recordIncident`, which only the active controller may call. The first incident in a deployment can be recorded immediately. After that, a second incident within 7 days reverts with `DecentralizationPhase: Incident cooldown active`. A fourth incident in the same phase reverts with `DecentralizationPhase: Incident cap reached` (`MAX_INCIDENTS_PER_PHASE` is 3). Each recorded incident resets the stability clock used by the milestone check. Advancing a phase sets `incidentsThisPhase` back to 0. The 7-day cooldown still applies until it has passed.

## Deliveries, confirmation, and disputes

During Bootstrap, the founder or the customer who created the delivery may call `completeDelivery`. During Hybrid and FullDAO, only that customer may complete it. A non-customer gets `DeliverySystem: Customer confirmation required`.

An authorized customer or driver can raise a dispute on `DeliveryTrackingSystem`. A disputed delivery cannot be completed until the active controller calls `resolveDispute` on `SimpleDeliverySystem`.

`emergencyAdjustRewardRate` works only in Bootstrap. `setRewardTokenRate` works only after Bootstrap. Both are controller calls. The platform fee is also a controller call, and it cannot be set above 10 percent.

## FullDAO governance

In FullDAO the active controller is the timelock, so token holders change parameters by proposal rather than by a direct call. `DeliveryToken` is an ERC20Votes token. A holder must delegate, including to themselves, before a balance counts as votes. `RLEGovernor` uses that voting power, a 4 percent quorum, and OpenZeppelin's `TimelockController`.

A token holder proposes an action on `SimpleDeliverySystem`, votes, and after the vote succeeds queues it. Execution waits for the timelock delay, then the timelock calls the delivery system. That is how FullDAO changes the platform fee (`setPlatformFeePercent`), the reward rate (`setRewardTokenRate`), dispute outcomes (`resolveDispute`), and incidents (`recordIncident`). The hybrid council is no longer the controller and cannot call those functions.

## Not upgradeable

These contracts are not upgradeable. There is no proxy, and the contract addresses stored at construction cannot be changed. Replacing a contract would require a governance-approved redeployment. The new deployment does not take the place of the contracts already on chain.

## Known limitation

Customers confirm their own deliveries. Colluding accounts, including Sybil wallets, could create self-dealing deliveries to earn RLE and inflate the delivery, driver, and GMV totals that advance the phase. The reward limits slow this per address: 10 minutes between deliveries, 50 deliveries per day, a 500 meter minimum, and a 30 kilometer distance cap. Those limits do not prevent the same pattern across many addresses.
