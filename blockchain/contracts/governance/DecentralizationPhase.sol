// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizationPhase
 * @notice Tracks platform maturity and advances the active controller when milestones are met
 * @dev Advancement is automatic and permissionless. Each successful advance moves exactly one
 *      phase and cannot move backward. Bootstrap uses the founder, Hybrid uses hybridCouncil,
 *      and FullDAO uses daoTimelock. The Ownable owner is a separate role, used for
 *      recordDelivery and recordIncident, and is expected to be SimpleDeliverySystem.
 *
 * Three phases:
 * 1. Bootstrap: founder is currentController
 * 2. Hybrid: hybridCouncil is currentController
 * 3. FullDAO: daoTimelock is currentController
 *
 * Once a phase's milestones are met, recordDelivery advances the phase and anyone may call
 * advancePhase. The founder cannot block, delay, or skip that handover.
 */
contract DecentralizationPhase is Ownable {
    /// @notice Enumeration of governance phases
    enum Phase {
        Bootstrap,  // Phase 1: founder is the active controller
        Hybrid,     // Phase 2: hybridCouncil is the active controller
        FullDAO     // Phase 3: daoTimelock is the active controller
    }

    /// @notice Current governance phase
    Phase public currentPhase;

    /// @notice Platform deployment timestamp
    uint64 public deploymentTime;

    /// @notice Last incident timestamp used by the stability clock
    uint64 public lastIncidentTime;

    /// @notice Deployer. Active controller during Bootstrap.
    address public immutable founder;

    /// @notice Active controller during Hybrid.
    address public immutable hybridCouncil;

    /// @notice Active controller during FullDAO. Intended to be a TimelockController.
    address public immutable daoTimelock;

    // ============ PHASE 1 → PHASE 2 MILESTONES ============

    /// @notice Minimum deliveries to advance to Hybrid phase
    uint32 public constant PHASE1_MIN_DELIVERIES = 10_000;

    /// @notice Minimum unique drivers to advance to Hybrid
    uint16 public constant PHASE1_MIN_DRIVERS = 100;

    /// @notice Minimum operating days to advance to Hybrid
    uint32 public constant PHASE1_MIN_DAYS = 180; // 6 months

    /// @notice Days without incidents required to advance to Hybrid
    uint16 public constant PHASE1_STABILITY_DAYS = 30;

    // ============ PHASE 2 → PHASE 3 MILESTONES ============

    /// @notice Minimum deliveries to advance to FullDAO
    uint32 public constant PHASE2_MIN_DELIVERIES = 1_000_000;

    /// @notice Minimum unique drivers to advance to FullDAO
    uint32 public constant PHASE2_MIN_DRIVERS = 10_000;

    /// @notice Minimum GMV to advance to FullDAO
    uint64 public constant PHASE2_MIN_GMV = 10_000_000 * 100; // $10M in cents

    /// @notice Days without incidents required to advance to FullDAO
    uint16 public constant PHASE2_STABILITY_DAYS = 90;

    /// @notice Minimum time between recorded incidents
    uint256 public constant INCIDENT_COOLDOWN = 7 days;

    /// @notice Maximum incidents that can reset the stability clock in one phase
    uint8 public constant MAX_INCIDENTS_PER_PHASE = 3;

    // ============ CURRENT METRICS ============

    /// @notice Total deliveries completed on platform
    uint32 public totalDeliveries;

    /// @notice Count of unique drivers who have completed at least one delivery
    uint16 public uniqueDrivers;

    /// @notice Total gross merchandise value processed (in cents)
    uint64 public totalGMV;

    /// @notice Mapping to track which drivers have completed deliveries
    mapping(address => bool) public hasCompletedDelivery;

    /// @notice Incidents recorded since the current phase began
    uint8 public incidentsThisPhase;

    /// @notice Timestamp of the last successful recordIncident call. Zero before the first incident.
    uint64 public lastIncidentRecordedAt;

    // ============ EVENTS ============

    /// @notice Emitted when platform advances to next governance phase
    event PhaseAdvanced(
        Phase newPhase,
        uint256 timestamp,
        uint256 deliveries,
        uint256 drivers
    );

    /// @notice Emitted when the active controller changes because the phase advanced
    event ControllerChanged(address previous, address next, Phase phase);

    /// @notice Emitted when an incident is recorded
    event IncidentRecorded(uint256 timestamp, string description);

    /// @notice Emitted when metrics are updated
    event MetricsUpdated(
        uint256 totalDeliveries,
        uint256 uniqueDrivers,
        uint256 totalGMV
    );

    /**
     * @notice Initializes the tracker in Bootstrap with the deployer as founder
     * @param hybridCouncil_ Controller used after the first advance. Must be non-zero and distinct.
     * @param daoTimelock_ Controller used at FullDAO. Must be non-zero and distinct.
     */
    constructor(address hybridCouncil_, address daoTimelock_) {
        require(hybridCouncil_ != address(0), "DecentralizationPhase: Hybrid council is zero");
        require(daoTimelock_ != address(0), "DecentralizationPhase: DAO timelock is zero");
        require(hybridCouncil_ != daoTimelock_, "DecentralizationPhase: Controllers must be distinct");
        require(hybridCouncil_ != msg.sender, "DecentralizationPhase: Hybrid council is founder");
        require(daoTimelock_ != msg.sender, "DecentralizationPhase: DAO timelock is founder");

        founder = msg.sender;
        hybridCouncil = hybridCouncil_;
        daoTimelock = daoTimelock_;

        currentPhase = Phase.Bootstrap;
        deploymentTime = uint64(block.timestamp);
        lastIncidentTime = uint64(block.timestamp);
        _transferOwnership(msg.sender);
    }

    /**
     * @notice Address that holds the phase's controller role
     * @return founder, hybridCouncil, or daoTimelock for the current phase
     */
    function currentController() public view returns (address) {
        if (currentPhase == Phase.Bootstrap) {
            return founder;
        }
        if (currentPhase == Phase.Hybrid) {
            return hybridCouncil;
        }
        return daoTimelock;
    }

    /// @notice True when the phase is Bootstrap
    function isBootstrap() public view returns (bool) {
        return currentPhase == Phase.Bootstrap;
    }

    /// @notice True when the phase is Hybrid
    function isHybrid() public view returns (bool) {
        return currentPhase == Phase.Hybrid;
    }

    /// @notice True when the phase is FullDAO
    function isFullDAO() public view returns (bool) {
        return currentPhase == Phase.FullDAO;
    }

    /**
     * @notice Checks if platform can advance from Bootstrap to Hybrid phase
     * @dev All milestone criteria must be met
     * @return bool True if ready to advance
     */
    function canAdvanceToHybrid() public view returns (bool) {
        if (currentPhase != Phase.Bootstrap) {
            return false;
        }

        uint256 daysSinceLaunch = (block.timestamp - deploymentTime) / 1 days;
        uint256 daysSinceIncident = (block.timestamp - lastIncidentTime) / 1 days;

        return (
            totalDeliveries >= _phase1MinDeliveries() &&
            uniqueDrivers >= _phase1MinDrivers() &&
            daysSinceLaunch >= _phase1MinDays() &&
            daysSinceIncident >= _phase1StabilityDays()
        );
    }

    /**
     * @notice Checks if platform can advance from Hybrid to FullDAO phase
     * @dev All milestone criteria must be met
     * @return bool True if ready to advance
     */
    function canAdvanceToFullDAO() public view returns (bool) {
        if (currentPhase != Phase.Hybrid) {
            return false;
        }

        uint256 daysSinceIncident = (block.timestamp - lastIncidentTime) / 1 days;

        return (
            totalDeliveries >= _phase2MinDeliveries() &&
            uniqueDrivers >= _phase2MinDrivers() &&
            totalGMV >= _phase2MinGMV() &&
            daysSinceIncident >= _phase2StabilityDays()
        );
    }

    /**
     * @notice Advances one phase when its milestones are already met
     * @dev Permissionless. Reverts at FullDAO, or when the next phase's milestones are not met.
     *      Cannot move the phase backward.
     */
    function advancePhase() external {
        if (currentPhase == Phase.FullDAO) {
            revert("DecentralizationPhase: Already at FullDAO");
        }
        if (!_tryAdvance()) {
            revert("DecentralizationPhase: Milestones not met");
        }
    }

    /**
     * @notice Records a delivery completion (called by DeliverySystem)
     * @dev Attempts one phase advance after the metrics are stored
     * @param driver Address of driver who completed delivery
     * @param fiatAmountCents Value of delivery in cents
     */
    function recordDelivery(address driver, address /* customer */, uint32 fiatAmountCents) external onlyOwner {
        totalDeliveries++;
        totalGMV += fiatAmountCents;

        // Track unique drivers
        if (!hasCompletedDelivery[driver]) {
            hasCompletedDelivery[driver] = true;
            uniqueDrivers++;
        }

        emit MetricsUpdated(totalDeliveries, uniqueDrivers, totalGMV);
        _tryAdvance();
    }

    /**
     * @notice Records a platform incident and resets the stability clock
     * @dev At most one incident every 7 days, and at most three per phase.
     *      The first incident is allowed immediately. Owner is expected to be SimpleDeliverySystem.
     * @param description Description of incident for transparency
     */
    function recordIncident(string memory description) external onlyOwner {
        if (lastIncidentRecordedAt != 0) {
            require(
                block.timestamp >= uint256(lastIncidentRecordedAt) + INCIDENT_COOLDOWN,
                "DecentralizationPhase: Incident cooldown active"
            );
        }
        require(
            incidentsThisPhase < MAX_INCIDENTS_PER_PHASE,
            "DecentralizationPhase: Incident cap reached"
        );

        incidentsThisPhase += 1;
        uint64 recordedAt = uint64(block.timestamp);
        lastIncidentRecordedAt = recordedAt;
        lastIncidentTime = recordedAt;

        emit IncidentRecorded(block.timestamp, description);
    }

    /**
     * @notice Gets current decentralization progress
     * @return phase Current governance phase
     * @return deliveryProgress Percentage progress toward delivery milestone (0-100)
     * @return driverProgress Percentage progress toward driver milestone (0-100)
     * @return timeProgress Percentage progress toward time milestone (0-100)
     * @return stabilityDays Days since last incident
     * @return canAdvance Whether platform can advance to next phase
     */
    function getProgress()
        external
        view
        returns (
            Phase phase,
            uint256 deliveryProgress,
            uint256 driverProgress,
            uint256 timeProgress,
            uint256 stabilityDays,
            bool canAdvance
        )
    {
        phase = currentPhase;
        stabilityDays = (block.timestamp - lastIncidentTime) / 1 days;

        if (currentPhase == Phase.Bootstrap) {
            deliveryProgress = (uint256(totalDeliveries) * 100) / _phase1MinDeliveries();
            driverProgress = (uint256(uniqueDrivers) * 100) / _phase1MinDrivers();
            timeProgress = ((block.timestamp - deploymentTime) * 100) / (_phase1MinDays() * 1 days);
            canAdvance = canAdvanceToHybrid();
        } else if (currentPhase == Phase.Hybrid) {
            deliveryProgress = (uint256(totalDeliveries) * 100) / _phase2MinDeliveries();
            driverProgress = (uint256(uniqueDrivers) * 100) / _phase2MinDrivers();
            timeProgress = 100; // Time milestone not applicable for Phase 2
            canAdvance = canAdvanceToFullDAO();
        } else {
            deliveryProgress = 100;
            driverProgress = 100;
            timeProgress = 100;
            canAdvance = false; // Already at final phase
        }

        return (phase, deliveryProgress, driverProgress, timeProgress, stabilityDays, canAdvance);
    }

    /**
     * @notice Gets milestone requirements for current phase
     * @return requiredDeliveries Minimum deliveries needed
     * @return requiredDrivers Minimum unique drivers needed
     * @return requiredDays Minimum operating days needed
     * @return requiredStabilityDays Days without incidents needed
     */
    function getCurrentMilestones()
        external
        view
        returns (
            uint256 requiredDeliveries,
            uint256 requiredDrivers,
            uint256 requiredDays,
            uint256 requiredStabilityDays
        )
    {
        if (currentPhase == Phase.Bootstrap) {
            return (
                _phase1MinDeliveries(),
                _phase1MinDrivers(),
                _phase1MinDays(),
                _phase1StabilityDays()
            );
        } else if (currentPhase == Phase.Hybrid) {
            return (
                _phase2MinDeliveries(),
                _phase2MinDrivers(),
                0, // No time requirement for Phase 2
                _phase2StabilityDays()
            );
        } else {
            return (0, 0, 0, 0); // Already at FullDAO
        }
    }

    /**
     * @dev Advances at most one phase when its milestones are met.
     *      Resets the per-phase incident count and emits PhaseAdvanced and ControllerChanged.
     * @return advanced True when the phase moved forward
     */
    function _tryAdvance() internal returns (bool) {
        address previous = currentController();
        Phase nextPhase;

        if (currentPhase == Phase.Bootstrap && canAdvanceToHybrid()) {
            nextPhase = Phase.Hybrid;
        } else if (currentPhase == Phase.Hybrid && canAdvanceToFullDAO()) {
            nextPhase = Phase.FullDAO;
        } else {
            return false;
        }

        currentPhase = nextPhase;
        incidentsThisPhase = 0;

        emit PhaseAdvanced(nextPhase, block.timestamp, totalDeliveries, uniqueDrivers);
        emit ControllerChanged(previous, currentController(), currentPhase);
        return true;
    }

    /// @dev Production Hybrid delivery threshold. A test contract may override this.
    function _phase1MinDeliveries() internal view virtual returns (uint32) {
        return PHASE1_MIN_DELIVERIES;
    }

    /// @dev Production Hybrid driver threshold. A test contract may override this.
    function _phase1MinDrivers() internal view virtual returns (uint16) {
        return PHASE1_MIN_DRIVERS;
    }

    /// @dev Production Hybrid operating-day threshold. A test contract may override this.
    function _phase1MinDays() internal view virtual returns (uint32) {
        return PHASE1_MIN_DAYS;
    }

    /// @dev Production Hybrid stability threshold. A test contract may override this.
    function _phase1StabilityDays() internal view virtual returns (uint16) {
        return PHASE1_STABILITY_DAYS;
    }

    /// @dev Production FullDAO delivery threshold. A test contract may override this.
    function _phase2MinDeliveries() internal view virtual returns (uint32) {
        return PHASE2_MIN_DELIVERIES;
    }

    /// @dev Production FullDAO driver threshold. A test contract may override this.
    function _phase2MinDrivers() internal view virtual returns (uint32) {
        return PHASE2_MIN_DRIVERS;
    }

    /// @dev Production FullDAO GMV threshold, in cents. A test contract may override this.
    function _phase2MinGMV() internal view virtual returns (uint64) {
        return PHASE2_MIN_GMV;
    }

    /// @dev Production FullDAO stability threshold. A test contract may override this.
    function _phase2StabilityDays() internal view virtual returns (uint16) {
        return PHASE2_STABILITY_DAYS;
    }
}
