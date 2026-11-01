# Chapter 3 (continued): System Design and Architecture

This file is the design portion of Chapter 3, as defined in Chapter 1, Section 1.10. The method is in `03_methodology.md`. Implementation is in `05_implementation.md`. Research questions are RQ1–RQ4 in `01_introduction.md`.

Section 2.8 requires this chapter to name the milestones and the powers transferred at each phase. The prototype's `DecentralizationPhase` contract records milestones and lets the owner advance an enum. Advancing the phase does not move `onlyOwner` authority, install a vote, or renounce the administrator. That limit is part of the design being evaluated under RQ3 and RQ4, not a completed handover.

## 4.1 Overall System Architecture

This section presents the architectural design of the decentralized delivery platform. The system follows a layered architecture pattern where each layer provides specific functionality while maintaining clear separation of concerns. This design approach enhances modularity, testability, and maintainability—critical properties for blockchain systems where bugs can be financially catastrophic and difficult to fix post-deployment (Antonopoulos & Wood, 2018).

### 4.1.1 High-Level Architecture

The system consists of the thesis contracts plus the Flutter application, wallet integration, and Firestore services required by Chapter 1. Figure 4.1 illustrates the architectural overview:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend Layer (Flutter)                        │
│                     Flutter Web/Mobile App                       │
│                  (User Interface & Wallet Integration)           │
└────────────────────────────┬────────────────────────────────────┘
                             │ Web3 RPC Calls
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Integration Layer                            │
│              SimpleDeliverySystem (Orchestrator)                 │
│      • Delivery lifecycle management                             │
│      • Fee calculation and tracking                              │
│      • Cross-contract coordination                               │
└──────┬───────────────────────────┬──────────────────────────────┘
       │                           │
       ▼                           ▼
┌──────────────────┐      ┌────────────────────────┐
│  Core Logic      │      │  Transparency Layer    │
│  BalancedReward  │      │  TrackingSystem        │
│  System          │      │  • GPS checkpoints     │
│  • Multi-factor  │      │  • Proof of delivery   │
│  • Anti-gaming   │      │  • Immutable history   │
│  • Adaptive rate │      └────────────────────────┘
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Economic Layer                              │
│                 DeliveryToken (ERC20)                            │
│              • 21M supply cap (Bitcoin-inspired)                 │
│              • Minting controlled by reward system               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Governance Layer                             │
│               DecentralizationPhase                              │
│      • Milestone tracking                                        │
│      • Progressive decentralization framework                    │
└─────────────────────────────────────────────────────────────────┘
```

**Figure 4.1**: Layered architecture of the decentralized delivery platform

### 4.1.2 Layer Responsibilities

**Frontend Layer** (in scope for RQ2):
- Provides the Flutter interface for customers, drivers, and an administrator
- Manages wallet connections (MetaMask, WalletConnect)
- Displays delivery status and reward information
- Submits transactions to smart contracts
- Keeps application data in Firestore, which remains under the operator

**Integration Layer** (SimpleDeliverySystem):
- Acts as the single entry point for all delivery operations
- Orchestrates interactions between tracking and reward systems
- Maintains the delivery record. In the current contract, creation sets status to in progress with an assigned driver. Completion and cancellation are separate.
- Enforces business rules (authorization, state transitions)
- Tracks platform fees for economic analysis

**Core Logic Layer** (BalancedRewardSystem):
- Implements the multi-factor balanced reward algorithm (PRIMARY CONTRIBUTION)
- Calculates points from volume, distance, rating, and diversity factors
- Applies anti-gaming protections (time limits, daily caps)
- Manages adaptive difficulty adjustment
- Tracks driver statistics for diversity bonuses

**Transparency Layer** (DeliveryTrackingSystem):
- Records immutable location checkpoints for each delivery
- Stores proof of delivery hashes (photos uploaded to IPFS)
- Provides public query interface for tracking history
- Supports RQ1 by keeping a tamper-resistant history of reported checkpoints. It does not prove that a physical shipment was at the reported place, and it does not claim to solve the Guam example in Section 1.2

**Economic Layer** (DeliveryToken):
- Standard ERC20 fungible token with 21 million supply cap
- Minting restricted to BalancedRewardSystem contract
- Enables rewards, potential future utility (payments, staking)

**Governance Layer** (DecentralizationPhase):
- Tracks platform metrics (deliveries, drivers, GMV, time, and stability)
- Exposes whether Bootstrap-to-Hybrid or Hybrid-to-FullDAO thresholds are met
- Does not, in the current code, transfer administrative powers when the phase changes

### 4.1.3 Interaction Flow Example

A typical delivery flow demonstrates how the layers interact:

1. **Frontend**: Customer creates delivery request through web app
2. **Integration Layer**: SimpleDeliverySystem creates delivery record, authorizes tracking
3. **Transparency Layer**: Driver submits location checkpoints as delivery progresses
4. **Integration Layer**: `completeDelivery` is restricted to the contract owner and records a rating. Customer confirmation of completion is not the rule in the current contract
5. **Core Logic Layer**: BalancedRewardSystem calculates reward based on distance, rating, diversity
6. **Economic Layer**: DeliveryToken mints tokens to driver's address
7. **Governance Layer**: DecentralizationPhase updates network statistics

This separation ensures that:
- Tracking continues to work even if reward calculation fails
- Reward logic can be upgraded without affecting delivery records
- Economic parameters can be adjusted without redeploying tracking
- Each component can be tested and audited independently

### 4.1.4 Security Boundaries

The architecture enforces several security boundaries:

**Trust Boundary**: Only SimpleDeliverySystem (owned by platform operator initially) can create deliveries and complete them. This prevents unauthorized token minting while maintaining decentralization potential through the governance layer.

**Authorization Boundary**: TrackingSystem uses explicit authorization—only addresses authorized for a specific delivery can add checkpoints. This prevents spam and ensures data integrity.

**Token Control Boundary**: DeliveryToken can only be minted by BalancedRewardSystem, which can only be called by SimpleDeliverySystem. This three-layer protection prevents inflation attacks.

These boundaries follow the principle of least privilege—each contract has exactly the permissions needed for its function and no more (Saltzer & Schroeder, 1975).

---

## 4.2 Smart Contract Design

This section details the design of each smart contract, focusing on state management, key algorithms, and design rationale.

### 4.2.1 DeliveryToken: Economic Foundation

DeliveryToken implements the ERC20 standard with a fixed supply cap, inspired by Bitcoin's scarcity model (Nakamoto, 2008).

**Design Decisions**:

1. **Supply Cap**: 21 million tokens (matching Bitcoin symbolically)
   - Rationale: Creates scarcity, prevents inflation, enables potential value appreciation
   - Implementation: Enforced in mint function with `require(totalSupply() + amount <= MAX_SUPPLY)`

2. **Controlled Minting**: Only BalancedRewardSystem can mint
   - Rationale: Prevents unauthorized inflation
   - Implementation: `onlyOwner` modifier on mint function, ownership transferred to reward system

3. **Standard Compliance**: Full ERC20 compatibility
   - Rationale: Ensures wallet/exchange compatibility
   - Implementation: Inherits OpenZeppelin's audited ERC20 implementation

**State Variables**:
```solidity
uint256 public constant MAX_SUPPLY = 21_000_000 * 10**18; // 21M with 18 decimals
```

**Key Functions**:
```solidity
function mint(address to, uint256 amount) external onlyOwner {
    require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds cap");
    _mint(to, amount);
}
```

The simplicity of this contract is intentional—complex token logic is avoided to minimize attack surface and gas costs. Additional features like burning, pausing, or snapshots are deferred to future work.

### 4.2.2 DeliveryTrackingSystem: Transparency Infrastructure

This contract supports RQ1 by providing a tamper-resistant audit trail of reported delivery events. Hashing limits what is published. It does not make the original report true.

**Design Decisions**:

1. **Checkpoint Structure**: Minimal data stored on-chain
   ```solidity
   struct Checkpoint {
       bytes32 locationHash;  // Hash of GPS coordinates (privacy)
       uint64 timestamp;      // When checkpoint was recorded
       string eventType;      // "pickup", "checkpoint", "delivery"
   }
   ```
   - Rationale: Storing full GPS coordinates on-chain is expensive (~20,000 gas per coordinate pair) and creates privacy issues. Hashing reduces gas costs and allows off-chain verification.

2. **Current Tracking Summary**: Quick access to latest state
   ```solidity
   struct CurrentTracking {
       bytes32 lastLocationHash;
       uint64 lastUpdateTime;
       bytes32 pickupProofHash;     // IPFS hash of pickup photo
       bytes32 deliveryProofHash;   // IPFS hash of delivery photo
       uint8 checkpointCount;
   }
   ```
   - Rationale: Applications often need only the latest status without querying full history. Separate summary struct reduces gas costs for common queries.

3. **Authorization Model**: Explicit per-delivery authorization
   ```solidity
   mapping(bytes32 => mapping(address => bool)) public authorizedTrackers;
   ```
   - Rationale: Prevents spam and ensures only relevant parties (driver, customer, platform) can update tracking data.

**Key Functions**:

```solidity
function addCheckpoint(bytes32 deliveryId, bytes32 locationHash, string memory eventType) 
    external 
{
    require(authorizedTrackers[deliveryId][msg.sender], "Not authorized");
    
    deliveryCheckpoints[deliveryId].push(Checkpoint({
        locationHash: locationHash,
        timestamp: uint64(block.timestamp),
        eventType: eventType
    }));
    
    CurrentTracking storage current = trackingSummary[deliveryId];
    current.lastLocationHash = locationHash;
    current.lastUpdateTime = uint64(block.timestamp);
    current.checkpointCount++;
    
    emit LocationCheckpoint(deliveryId, locationHash, uint64(block.timestamp), eventType);
}
```

**Design Rationale**: The event emission is crucial—it allows lightweight clients to reconstruct tracking history from event logs without querying storage, reducing costs (Delmolino et al., 2016).

### 4.2.3 BalancedRewardSystem: Core Contribution

This contract implements the experimental RLE reward formula from Section 1.8: volume, distance, rating, and diversity, with limits intended to reduce simple manipulation. It does not establish that the formula is fair or resistant to coordinated attacks. Those claims depend on the Chapter 4 simulations.

**4.2.3.1 Multi-Factor Reward Algorithm**

The algorithm calculates rewards from four interdependent factors:

**Formula**:
```
Total Points = Volume Points + Distance Points + Rating Points + Diversity Bonus

Token Reward = (Total Points × Current Rate) / 100
```

Where:
- **Volume Points** = 100 (baseline for completing any delivery)
- **Distance Points** = f(distance) with diminishing returns
- **Rating Points** = rating × 20 (rating is 1-5 stars)
- **Diversity Bonus** = g(delivery variety) ∈ {0, 25, 50}

**Distance Points Function** (with diminishing returns):
```solidity
function calculateDistancePoints(uint256 distanceMeters) public pure returns (uint256) {
    if (distanceMeters < 500) return 0;  // Minimum distance filter
    
    uint256 effectiveDistance = min(distanceMeters, 30000);  // Cap at 30km
    uint256 distanceKm = effectiveDistance / 1000;
    uint256 basePoints = distanceKm * 10;
    
    // Apply efficiency tiers
    if (distanceMeters <= 5000)        return basePoints;         // 0-5km: 100%
    else if (distanceMeters <= 15000)  return basePoints * 90/100;  // 5-15km: 90%
    else if (distanceMeters <= 30000)  return basePoints * 80/100;  // 15-30km: 80%
    else                               return basePoints * 70/100;  // >30km: 70%
}
```

**Rationale for Diminishing Returns**: 
- Prevents "distance farming" where drivers only accept long deliveries
- Reflects real-world operational costs (longer deliveries have higher risk, time commitment)
- Encourages balanced delivery mix, improving platform responsiveness

**Diversity Bonus Function**:
```solidity
function calculateDiversityBonus(address driver, uint256 distanceMeters) 
    public view returns (uint256) 
{
    DiversityTracker memory diversity = diversityTrackers[driver];
    
    // Count delivery types (including current one hypothetically)
    uint8 typesUsed = 0;
    if (shortDeliveriesToday > 0 || distanceMeters < 5000) typesUsed++;
    if (mediumDeliveriesToday > 0 || (5000 <= distanceMeters < 15000)) typesUsed++;
    if (longDeliveriesToday > 0 || distanceMeters >= 15000) typesUsed++;
    
    if (typesUsed == 3) return 50;      // All three types: +50 points
    else if (typesUsed == 2) return 25;  // Two types: +25 points
    else return 0;                       // Only one type: no bonus
}
```

**Rationale for Diversity**:
- Incentivizes drivers to accept varied deliveries rather than cherry-picking
- Improves platform coverage and customer experience
- Creates a natural anti-gaming mechanism—maximizing rewards requires variety

**Example Calculation**:
```
Scenario: 10km delivery, 5-star rating, driver has done short + medium today

Volume:    100 points  (baseline)
Distance:  90 points   (10km × 10 points/km × 90% efficiency)
Rating:    100 points  (5 stars × 20 points/star)
Diversity: 50 points   (all 3 types achieved with this delivery)
─────────────────────
Total:     340 points

At current rate of 1.0 (initial):
Reward = 340 × 1.0 / 100 = 3.40 RLE tokens
```

**4.2.3.2 Anti-Gaming Protections**

The system implements multiple safeguards against manipulation:

1. **Time-Based Cooldown**: 10-minute minimum between deliveries
   ```solidity
   require(
       block.timestamp >= stats.lastDeliveryTime + 10 minutes,
       "Must wait 10 minutes between deliveries"
   );
   ```
   - Prevents rapid-fire fake deliveries
   - Forces realistic spacing between jobs

2. **Daily Delivery Cap**: Maximum 50 deliveries per driver per day
   ```solidity
   require(stats.deliveriesToday < 50, "Daily delivery limit reached");
   ```
   - Prevents bot spam
   - Realistic limit (50 deliveries = ~1 per 30 minutes for 24 hours)

3. **Minimum Distance**: 500 meters minimum for any reward
   ```solidity
   require(distanceMeters >= 500, "Distance too short");
   ```
   - Prevents "next door" fake deliveries
   - Ensures deliveries have real economic value

4. **Distance Cap**: Maximum 30km for points calculation
   ```solidity
   uint256 effectiveDistance = min(distanceMeters, 30000);
   ```
   - Prevents extreme distance gaming
   - 30km is still substantial (covers most urban delivery areas)

5. **Packed State for Gas Efficiency**: Driver stats use optimized storage
   ```solidity
   struct DriverStats {
       uint64 lastDeliveryTime;   // Packed: slot 1
       uint16 deliveriesToday;    // Packed: slot 1
       uint64 lastDayReset;       // Packed: slot 1
       uint32 totalDeliveries;    // Packed: slot 2
       uint256 totalEarnedTokens; // Slot 3
       uint256 totalPointsEarned; // Slot 4
   }
   ```
   - Saves 2 storage slots per driver (40,000 gas per update)
   - `uint64` timestamps sufficient until year 2554
   - `uint16` daily counter supports up to 65,535 deliveries/day (far beyond 50 limit)

**4.2.3.3 Adaptive Difficulty Adjustment**

Inspired by Bitcoin's difficulty adjustment (Nakamoto, 2008), the system adjusts token distribution rate based on network velocity:

```solidity
function checkAndAdjustRate() internal {
    if (block.timestamp < lastAdjustmentTime + 7 days) return;
    
    uint256 deliveriesSinceCheck = totalDeliveriesCompleted - lastAdjustmentDeliveries;
    uint256 timeElapsed = block.timestamp - lastAdjustmentTime;
    uint256 dailyVelocity = (deliveriesSinceCheck * 1 days) / timeElapsed;
    
    if (dailyVelocity > TARGET_DAILY_DELIVERIES * 2) {
        // Network too fast - reduce rate by 10%
        currentTokenRate = currentTokenRate * 90 / 100;
    } else if (dailyVelocity < TARGET_DAILY_DELIVERIES / 2) {
        // Network too slow - increase rate by 10%
        currentTokenRate = currentTokenRate * 110 / 100;
    }
    
    lastAdjustmentTime = block.timestamp;
    lastAdjustmentDeliveries = totalDeliveriesCompleted;
}
```

**Rationale**:
- Target: 1,000 deliveries/day for stable rate
- If network grows 2x faster than expected, reduce rewards to slow token supply growth
- If network grows slower, increase rewards to incentivize adoption
- Ensures 21M supply lasts for extended network lifetime
- Self-stabilizing mechanism inspired by proof-of-work difficulty (Back, 2002)

**Design Choice**: Weekly adjustment window balances responsiveness with stability—daily adjustments would be too volatile, monthly too slow.

### 4.2.4 SimpleDeliverySystem: Integration Orchestrator

This contract serves as the coordination layer, managing the delivery lifecycle and ensuring proper interaction between all components.

**State Machine Design**:

```
    ┌─────────┐
    │ Created │
    └────┬────┘
         │ (automatic transition)
         ▼
  ┌─────────────┐
  │ InProgress  │
  └──────┬──────┘
         │
         ├──► Complete (with rating) ──► [Trigger Reward Calculation]
         │
         ├──► Cancel (before pickup)
         │
         └──► Disputed (customer/driver raises dispute)
```

**Key Design Pattern: Orchestration**

Rather than having contracts directly call each other in complex ways, SimpleDeliverySystem acts as a coordinator:

```solidity
function completeDelivery(bytes32 deliveryId, uint8 rating) external onlyOwner {
    Delivery storage delivery = deliveries[deliveryId];
    require(delivery.status == Status.InProgress, "Not in progress");
    require(rating >= 1 && rating <= 5, "Invalid rating");
    
    // Update delivery state
    delivery.status = Status.Completed;
    delivery.completedAt = uint64(block.timestamp);
    delivery.rating = rating;
    
    // Trigger reward calculation (Core Logic Layer)
    uint256 driverReward = rewardSystem.processReward(
        delivery.driver,
        delivery.distanceMeters,
        rating
    );
    
    // Mint customer reward (simple fixed amount for thesis)
    token.mint(delivery.customer, 2 * 10**18);  // 2 RLE for rating
    
    // Update governance metrics (Governance Layer)
    decentralizationPhase.recordDelivery(
        delivery.driver,
        delivery.customer,
        delivery.fiatAmountCents
    );
    
    emit DeliveryCompleted(deliveryId, delivery.driver, delivery.fiatAmountCents, driverReward, rating);
}
```

**Benefits of Orchestration Pattern**:
- Single transaction executes all related operations atomically
- Easier to test (fewer inter-contract dependencies)
- Clear transaction boundaries for gas estimation
- Simpler upgrade path (replace orchestrator without changing layer contracts)

**Platform Fee Tracking**:

The contract tracks a platform-fee percentage for accounting (discussed with the other measurements in Chapter 4):

```solidity
uint256 public platformFeePercent = 2;  // Fixed 2% for thesis
uint256 public totalFeesCollectedCents; // Accumulated fees in USD cents

function createDelivery(...) external onlyOwner {
    // ... create delivery logic ...
    
    uint256 platformFee = (fiatAmountCents * platformFeePercent) / 100;
    totalFeesCollectedCents += platformFee;
    
    emit PlatformFeeCollected(deliveryId, platformFee);
}
```

This provides data for comparative analysis against traditional platforms (Uber: 30%, System: 2%).

### 4.2.5 DecentralizationPhase: Governance Framework

This contract is the milestone mechanism for RQ3. It records readiness for a later handover. It does not perform that handover.

**Three-phase labels in the prototype**:

1. **Bootstrap**: The contract starts here, with the deployer as owner. Thresholds to be eligible for Hybrid are 10,000 deliveries, 100 unique drivers, 180 days since deployment, and 30 days since the last recorded incident.
2. **Hybrid**: The enum can move here only if the owner calls `advancePhase` after those thresholds are met. No shared vote is installed, and owner functions on the delivery, reward, and tracking contracts are unchanged.
3. **FullDAO**: Eligibility requires 1,000,000 deliveries, 10,000 unique drivers, $10,000,000 GMV, and 90 days since the last incident. Reaching this label still does not create token voting or remove the owner.

`advancePhase` and `recordDelivery` are `onlyOwner`. The contract comment states that a community vote is future work and that the thesis version demonstrates milestone checking. Section 2.8 asks Chapter 3 to list the powers transferred at each phase. In this design, the powers transferred are none.

**Milestone checks in the prototype** (`blockchain/contracts/governance/DecentralizationPhase.sol`):

```solidity
uint32 public constant PHASE1_MIN_DELIVERIES = 10_000;
uint16 public constant PHASE1_MIN_DRIVERS = 100;
uint32 public constant PHASE1_MIN_DAYS = 180;
uint16 public constant PHASE1_STABILITY_DAYS = 30;

function canAdvanceToHybrid() public view returns (bool) {
    if (currentPhase != Phase.Bootstrap) return false;
    uint256 daysSinceLaunch = (block.timestamp - deploymentTime) / 1 days;
    uint256 daysSinceIncident = (block.timestamp - lastIncidentTime) / 1 days;
    return (
        totalDeliveries >= PHASE1_MIN_DELIVERIES &&
        uniqueDrivers >= PHASE1_MIN_DRIVERS &&
        daysSinceLaunch >= PHASE1_MIN_DAYS &&
        daysSinceIncident >= PHASE1_STABILITY_DAYS
    );
}

function advancePhase() external onlyOwner {
    // Requires canAdvanceToHybrid or canAdvanceToFullDAO, then updates currentPhase only.
}
```

**Design rationale**:
- Objective thresholds make readiness visible instead of leaving it as an unmeasured promise.
- Time and stability requirements keep a phase change from happening on volume alone.
- The owner must still call `advancePhase`, so the motivation problem in Section 2.8 is only partly addressed: the code checks the milestones, and the administrator still decides whether to advance the label.
- Token-weighted voting, timelocks, and role renunciation from Section 2.8 are not part of this contract.

---

## 4.3 Data Flow and Interactions

This section illustrates how data flows through the system during key operations.

### 4.3.1 Complete Delivery Flow (End-to-End)

```
[Customer Frontend]
      │
      │ 1. Submit rating (1-5 stars)
      ▼
[SimpleDeliverySystem]
      │
      │ 2. Validate delivery state (must be InProgress)
      │ 3. Update delivery record (status = Completed)
      │
      ├──► 4a. Call TrackingSystem.submitDeliveryProof(photoHash)
      │         └─► Stores IPFS hash of delivery photo
      │
      ├──► 4b. Call RewardSystem.processReward(driver, distance, rating)
      │         │
      │         │ 5. Calculate balanced points
      │         │    • Volume: 100
      │         │    • Distance: f(distance) with diminishing returns
      │         │    • Rating: rating × 20
      │         │    • Diversity: g(driver history)
      │         │
      │         │ 6. Apply current adaptive rate
      │         │    tokenReward = points × rate / 100
      │         │
      │         │ 7. Update driver statistics
      │         │
      │         └──► 8. Call Token.mint(driver, tokenReward)
      │                   └─► Mints RLE tokens to the driver
      │
      └──► 9. Update DecentralizationPhase metrics
                 └─► Increment totalDeliveries, uniqueDrivers, totalGMV
                 The current contracts do not mint a customer reward.

[Blockchain Events Emitted]
      • DeliveryCompleted(id, driver, fiatAmount, tokenReward, rating)
      • RewardCalculated(driver, distance, rating, points, tokenReward)
      • Transfer(0x0, driver, tokenReward)  // ERC20 mint event
```

**Gas cost breakdown** (measured in Chapter 4, `06_evaluation.md`):
- Update delivery state: ~30,000 gas
- Reward calculation: ~150,000 gas
- Token minting: ~50,000 gas
- Governance update: ~20,000 gas
- **Total: ~250,000 gas** (varies based on storage access patterns)

### 4.3.2 Tracking Checkpoint Flow

```
[Driver Mobile App]
      │
      │ 1. Submit GPS location (latitude, longitude)
      ▼
[Off-chain Service]
      │
      │ 2. Hash GPS coordinates (privacy)
      │    locationHash = keccak256(abi.encodePacked(lat, lng, salt))
      ▼
[SimpleDeliverySystem]
      │
      │ 3. Forward to TrackingSystem
      ▼
[DeliveryTrackingSystem]
      │
      │ 4. Verify authorization
      │ 5. Append checkpoint to array
      │ 6. Update current tracking summary
      │ 7. Emit LocationCheckpoint event
      ▼
[Frontend Listening to Events]
      │
      │ 8. Display updated location on map
      │ 9. Show progress timeline
```

**Privacy Consideration**: GPS coordinates are hashed before blockchain storage. Original coordinates stored off-chain (IPFS or traditional database) and can be revealed if dispute occurs. This balances transparency with privacy (Zyskind et al., 2015).

---

## 4.4 Frontend Application Design (Optional Demonstration)

While the smart contracts are the core contribution, a simple frontend demonstrates usability.

**Architecture** (Flutter/Dart):

```
┌─────────────────────────────────────────────────────┐
│              Presentation Layer                      │
│  Screens: Landing, Login, Customer Home, Driver Home│
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│             Business Logic Layer                     │
│  Services: WalletService, ContractService,          │
│            DeliveryService, LocationService          │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│            Data/Integration Layer                    │
│  web3dart: Ethereum RPC communication                │
│  http: REST API calls (for off-chain data)          │
└──────────────────────────────────────────────────────┘
```

**Key Components**:

1. **WalletService**: Manages MetaMask connection
2. **ContractService**: Handles smart contract ABI loading and method calls
3. **DeliveryService**: Business logic for creating/completing deliveries
4. **LocationService**: GPS tracking and distance calculation

**Example Interaction** (TypeScript/Dart pseudo-code):

```dart
class DeliveryService {
  final ContractService contractService;
  
  Future<BigInt> completeDelivery(String deliveryId, int rating) async {
    // Call smart contract
    final tx = await contractService.callFunction(
      contract: 'SimpleDeliverySystem',
      function: 'completeDelivery',
      params: [deliveryId, rating]
    );
    
    // Wait for confirmation
    final receipt = await tx.wait();
    
    // Parse reward from event
    final rewardEvent = receipt.events.firstWhere(
      (e) => e.event == 'RewardCalculated'
    );
    return rewardEvent.args['tokenReward'];
  }
}
```

However, the frontend is **not required** for thesis validity—the smart contracts can be demonstrated via:
- Hardhat console interactions
- Etherscan/blockchain explorer screenshots
- Test transaction logs

---

## 4.5 Design Patterns and Best Practices Applied

This system employs several established design patterns from software engineering and blockchain development:

### 4.5.1 Separation of Concerns
Each contract has a single, well-defined responsibility. This follows the Single Responsibility Principle (Martin, 2008).

### 4.5.2 Checks-Effects-Interactions Pattern
Functions follow this order to prevent reentrancy attacks (ConsenSys, 2020):
1. **Checks**: Validate inputs and state (require statements)
2. **Effects**: Update internal state
3. **Interactions**: Call external contracts

Example:
```solidity
function completeDelivery(bytes32 deliveryId, uint8 rating) external {
    // Checks
    require(delivery.status == Status.InProgress, "Not in progress");
    require(rating >= 1 && rating <= 5, "Invalid rating");
    
    // Effects
    delivery.status = Status.Completed;
    delivery.completedAt = block.timestamp;
    
    // Interactions
    rewardSystem.processReward(driver, distance, rating);
}
```

### 4.5.3 Access Control Pattern
Functions use modifiers for authorization:
- `onlyOwner`: Platform operator only (Bootstrap phase)
- `authorizedTrackers[deliveryId][msg.sender]`: Per-delivery authorization
- Custom modifiers for phase-based access control

### 4.5.4 Pull Over Push Pattern
For token distribution, contracts mint directly to recipients rather than requiring claims. This is safe because:
- Recipients are known (driver addresses from delivery records)
- No loops over unbounded arrays
- Gas costs are predictable

### 4.5.5 Circuit Breaker Pattern (Future Work)
While not implemented in thesis version, production would include emergency pause functionality:
```solidity
// Future enhancement
bool public paused = false;
modifier whenNotPaused() {
    require(!paused, "Contract paused");
    _;
}
```

---

## 4.6 Design Trade-offs and Rationale

Every design involves trade-offs. This section explicitly discusses choices made and alternatives considered.

### 4.6.1 On-Chain vs Off-Chain Data

**Decision**: Store minimal data on-chain, keep bulky data off-chain

**On-Chain**:
- Delivery metadata (IDs, amounts, timestamps)
- Hashes of location data
- Reward calculations
- Token balances

**Off-Chain** (IPFS/traditional database):
- Full GPS coordinates
- Photos (pickup/delivery proof)
- User profiles
- Chat messages

**Rationale**:
- Gas costs: Storing 1 KB on-chain costs ~640,000 gas (~$38 on mainnet)
- Privacy: Full GPS history unnecessary for most users
- Performance: Querying large datasets faster off-chain
- Trade-off: Reduces decentralization slightly, increases complexity

### 4.6.2 Permissioned vs Permissionless

**Decision**: Permissioned creation (onlyOwner), permissionless queries

**Permissioned**:
- Creating deliveries (requires off-chain verification)
- Completing deliveries (requires customer confirmation)
- Adjusting system parameters

**Permissionless**:
- Querying tracking history
- Viewing token balances
- Reading reward calculations

**Rationale**:
- Prevents spam (anyone could create fake deliveries)
- Maintains quality control during Bootstrap phase
- Aligns with progressive decentralization model
- Trade-off: Not fully decentralized initially, but path exists via governance

### 4.6.3 Fixed vs Dynamic Platform Fee

**Decision**: Fixed 2% fee for thesis

**Rationale**:
- Simplifies economic analysis (Chapter 6)
- Clear comparison to traditional platforms (30%)
- Dynamic fees would require governance mechanism (future work)
- 2% chosen to cover operational costs while remaining competitive

### 4.6.4 Simple vs Complex Diversity Bonus

**Decision**: Simple 3-tier system (short/medium/long) with binary bonuses (0/25/50)

**Alternatives Considered**:
- Continuous function based on exact distance distribution
- More granular categories (5+ tiers)
- Time-weighted diversity (harder to game with patterns)

**Rationale**:
- Gas efficiency: Simple categorization saves ~10,000 gas per calculation
- Understandability: Drivers can easily optimize strategy
- Sufficient gaming prevention: Even simple version makes exploitation difficult
- Trade-off: Less precise, but 90% of benefits for 30% of complexity

---

## 4.7 Design Summary

This design section specifies how RLE represents the delivery lifecycle and where control remains centralized:

**RQ1**: DeliveryTrackingSystem stores hashed checkpoints and proof hashes so independent parties can inspect a reported history. The design does not verify the physical event.

**RQ2**: SimpleDeliverySystem, the Flutter application, wallets, and Firestore are the integrated path from creation toward completion. Completion in the contract is an owner function. Driver acceptance is not an on-chain state change in the current lifecycle: creation sets the delivery to in progress with an assigned driver.

**RQ3**: DecentralizationPhase measures milestone readiness. Phase labels do not transfer administrator powers, and the RLE token is a reward, not voting power.

**RQ4**: The design leaves administrator completion, owner-triggered phase changes, open questions about hash guessability, and operator control of Firebase as limitations to measure in Chapter 4.

Implementation of these designs continues in `05_implementation.md`.

---

## References

Antonopoulos, A. M., & Wood, G. (2018). *Mastering Ethereum: Building Smart Contracts and DApps*. O'Reilly Media.

Back, A. (2002). Hashcash-a denial of service counter-measure. *Technical report*.

ConsenSys. (2020). Ethereum smart contract best practices. Retrieved from https://consensys.github.io/smart-contract-best-practices/

Delmolino, K., Arnett, M., Kosba, A., Miller, A., & Shi, E. (2016). Step by step towards creating a safe smart contract: Lessons and insights from a cryptocurrency lab. In *International Conference on Financial Cryptography and Data Security* (pp. 79-94). Springer.

Leshner, R., & Hayes, G. (2019). Compound: The money market protocol. *Whitepaper*.

Martin, R. C. (2008). *Clean Code: A Handbook of Agile Software Craftsmanship*. Prentice Hall.

Nakamoto, S. (2008). Bitcoin: A peer-to-peer electronic cash system. *Whitepaper*.

Saltzer, J. H., & Schroeder, M. D. (1975). The protection of information in computer systems. *Proceedings of the IEEE*, 63(9), 1278-1308.

Zyskind, G., Nathan, O., & Pentland, A. (2015). Decentralizing privacy: Using blockchain to protect personal data. In *2015 IEEE Security and Privacy Workshops* (pp. 180-184). IEEE.

---

**Chapter 4 Word Count**: ~6,800 words (~8.5 pages)

**Code Snippets**: 18 examples (20% of content)

**Diagrams**: 3 architectural diagrams

**References**: 10 sources

**Status**: Design section of Chapter 3, aligned with Chapters 1 and 2.

