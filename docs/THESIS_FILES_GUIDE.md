# Thesis files guide

The thesis text is a Word document maintained outside this repository. This guide lists the code and data in the current repo that support that document.

## Repository tree

```
delivery-dapp-flutter/
├── blockchain/
│   ├── contracts/          # Solidity sources
│   ├── test/               # Hardhat tests
│   ├── scripts/            # deploy-thesis.ts, test-delivery.ts
│   ├── simulation/         # thesis_evaluator.py
│   ├── results/            # thesis_evaluation_results.json
│   └── README.md
├── app/                    # Flutter web and mobile client
├── docs/THESIS_FILES_GUIDE.md
├── TODO.md
└── DeliveryDApp_Documentation.md
```

## Smart contracts

Sources are in `blockchain/contracts/`.

- `core/SimpleDeliverySystem.sol` — orchestrates a delivery. It is not Ownable. It calls the other contracts, which it owns.
- `core/DeliveryTrackingSystem.sol` — checkpoints and disputes for a delivery.
- `core/RatingSystem.sol` — ratings, submitted by its owner (`SimpleDeliverySystem`).
- `core/BalancedRewardSystem.sol` — distance, rating, and volume reward calculation, with per-address limits.
- `tokens/DeliveryToken.sol` — ERC-20 votes token named Reliable Logistics Exchange (RLE). Owned by `BalancedRewardSystem`.
- `governance/DecentralizationPhase.sol` — phase milestones and the active controller.
- `governance/RLEGovernor.sol` — token-holder proposals executed through the timelock.
- `test/TestDecentralizationPhase.sol` — test-only subclass with lowered milestones. Production thresholds are unchanged.

OpenZeppelin's `TimelockController` is deployed with these contracts. It is not a source file in this repo.

## Progressive decentralization

`currentController()` returns one address:

- Bootstrap: the founder, the address that deployed `DecentralizationPhase`.
- Hybrid: `hybridCouncil`, set in the constructor.
- FullDAO: `daoTimelock`. Token holders act through `RLEGovernor`, which proposes, and the timelock executes.

`recordDelivery`, called at the end of `completeDelivery`, advances at most one phase in that same transaction when the milestones are met. Anyone may also call `advancePhase()` once they are met. The phase never moves backward.

`recordIncident` is reached through `SimpleDeliverySystem` and only the active controller may call it. The first incident can be recorded immediately. After that, another incident within 7 days is rejected, and a fourth incident in the same phase is rejected (`MAX_INCIDENTS_PER_PHASE` is 3).

During Bootstrap, the founder or that delivery's customer may complete it. During Hybrid and FullDAO, only the customer may complete it.

## Tests

All tests are in `blockchain/test/`. From `blockchain/`, run `npx hardhat test`.

Current result: 83 passing, 3 failing. The failures are gas-threshold assertions and are left in place:

- `BalancedRewardSystem.test.ts` — reward math, distance tiers, and per-address limits. `processReward` exceeds its gas cap.
- `DeliveryTrackingSystem.test.ts` — checkpoints and disputes. `addCheckpoint` exceeds its gas cap.
- `IntegrationFlow.test.ts` — create, checkpoint, and complete across the owned contracts. The full delivery flow exceeds its gas cap.
- `DecentralizationPhase.test.ts` — production milestone constants and `recordDelivery`.
- `ProgressiveDecentralization.test.ts` — automatic and permissionless handover, incidents, customer confirmation, and a FullDAO proposal through the governor and timelock. Uses `TestDecentralizationPhase`.
- `RatingSystem.test.ts` — only the owner may submit or update a rating.
- `DeliveryToken.test.ts` — name, symbol, and vote delegation.

## Scripts

`blockchain/scripts/deploy-thesis.ts` deploys `DeliveryToken`, `TimelockController`, `RLEGovernor`, `DeliveryTrackingSystem`, `RatingSystem`, `BalancedRewardSystem`, `DecentralizationPhase`, and `SimpleDeliverySystem`. It transfers token ownership to the reward contract, and reward, tracking, rating, and phase ownership to `SimpleDeliverySystem`. It then checks those owners, `currentController`, `hybridCouncil`, `daoTimelock`, and the timelock roles (governor has proposer and canceller; the deployer no longer has admin). It writes `app/assets/config/contracts.localhost.json`, copies the Hardhat artifact to `app/assets/abi/SimpleDeliverySystem.json`, and writes the detected host to git-ignored `app/assets/config/dev_host.json`.

`blockchain/scripts/test-delivery.ts` reads that localhost config and has the customer create and complete one delivery. It is not part of `npx hardhat test`.

## Simulation

`blockchain/simulation/thesis_evaluator.py` is the economic evaluation script. Its output is `blockchain/results/thesis_evaluation_results.json`.

## Flutter app

`app/lib/screens/` holds landing, login, registration, customer home, driver home, admin home, analytics, and the not-found screen. `app/lib/services/` holds blockchain access (contracts, wallets, network), delivery actions, user accounts, and Firestore analytics. `app/lib/widgets/` holds shared status and wallet widgets, delivery cards and the create-delivery dialog, and the wallet selector.

`ContractService` loads addresses from `assets/config/contracts.localhost.json`, then `assets/config/contracts.json`. It loads the ABI from `assets/abi/SimpleDeliverySystem.json`. In development it reads `assets/config/dev_host.json` when that file exists; otherwise the RPC host stays `10.0.2.2`.

## Thesis appendices

Use these as appendix material:

- Contract sources in `blockchain/contracts/` (not `contracts/test/TestDecentralizationPhase.sol`, which exists only to shorten milestones in tests).
- Hardhat tests in `blockchain/test/`.
- The simulation in `blockchain/simulation/thesis_evaluator.py` and the result file in `blockchain/results/`.
