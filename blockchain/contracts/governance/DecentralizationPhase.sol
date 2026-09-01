// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizationPhase
 * @notice Tracks platform maturity and manages milestone-based decentralization transitions
 * @dev Framework demonstration for progressive governance (not full voting implementation)
 * 
 * Academic Purpose: Addresses RQ2 (decentralization impact) by proposing milestone-based
 * governance transition framework as alternative to arbitrary time-based decentralization.
 * 
 * Three Phases:
 * 1. Bootstrap: Founder control for rapid iteration and bug fixes
 * 2. Hybrid: Shared control (framework only, full voting in future work)
 * 3. FullDAO: Community control (conceptual, implementation future work)
 * 
 * Thesis Contribution: Demonstrates that decentralization readiness should be measured
 * by platform maturity metrics (deliveries, users, stability) rather than arbitrary timelines.
 */
contract DecentralizationPhase is Ownable {
    /// @notice Enumeration of governance phases
    enum Phase {
        Bootstrap,  // Phase 1: Centralized (founder control)
        Hybrid,     // Phase 2: Transitioning (shared control)
        FullDAO     // Phase 3: Decentralized (community control)
    }
    
    /// @notice Current governance phase
    Phase public currentPhase;
    
    /// @notice Platform deployment timestamp
    uint64 public deploymentTime;
    
    /// @notice Last incident/bug timestamp (for stability tracking)
    uint64 public lastIncidentTime;
    
    // ============ PHASE 1 → PHASE 2 MILESTONES ============
    
    /// @notice Minimum deliveries to advance to Hybrid phase
    uint32 public constant PHASE1_MIN_DELIVERIES = 10_000;
    
    /// @notice Minimum unique drivers to advance to Hybrid
    uint16 public constant PHASE1_MIN_DRIVERS = 100;
    
    /// @notice Minimum operating days to advance to Hybrid
    uint32 public constant PHASE1_MIN_DAYS = 180; // 6 months
    
    /// @notice Days without incidents required to advance
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
    
    // ============ CURRENT METRICS ============
    
    /// @notice Total deliveries completed on platform
    uint32 public totalDeliveries;
    
    /// @notice Count of unique drivers who have completed at least one delivery
    uint16 public uniqueDrivers;
    
    /// @notice Total gross merchandise value processed (in cents)
    uint64 public totalGMV;
    
    /// @notice Mapping to track which drivers have completed deliveries
    mapping(address => bool) public hasCompletedDelivery;
    
    // ============ EVENTS ============
    
    /// @notice Emitted when platform advances to next governance phase
    event PhaseAdvanced(
        Phase newPhase,
        uint256 timestamp,
        uint256 deliveries,
        uint256 drivers
    );
    
    /// @notice Emitted when an incident is recorded
    event IncidentRecorded(uint256 timestamp, string description);
    
    /// @notice Emitted when metrics are updated
    event MetricsUpdated(
        uint256 totalDeliveries,
        uint256 uniqueDrivers,
        uint256 totalGMV
    );
    
    /**
     * @notice Initializes the decentralization tracker
     * @dev Starts in Bootstrap phase with founder control
     */
    constructor() {
        currentPhase = Phase.Bootstrap;
        deploymentTime = uint64(block.timestamp);
        lastIncidentTime = uint64(block.timestamp);
        _transferOwnership(msg.sender);
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
            totalDeliveries >= PHASE1_MIN_DELIVERIES &&
            uniqueDrivers >= PHASE1_MIN_DRIVERS &&
            daysSinceLaunch >= PHASE1_MIN_DAYS &&
            daysSinceIncident >= PHASE1_STABILITY_DAYS
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
            totalDeliveries >= PHASE2_MIN_DELIVERIES &&
            uniqueDrivers >= PHASE2_MIN_DRIVERS &&
            totalGMV >= PHASE2_MIN_GMV &&
            daysSinceIncident >= PHASE2_STABILITY_DAYS
        );
    }
    
    /**
     * @notice Advances platform to next governance phase
     * @dev Requires all milestones to be met; emits event for transparency
     * 
     * Academic Note: In future implementation, phase advancement would require
     * community governance vote. For thesis, demonstrates milestone checking.
     */
    function advancePhase() external onlyOwner {
        if (currentPhase == Phase.Bootstrap) {
            require(canAdvanceToHybrid(), "DecentralizationPhase: Milestones not met for Hybrid");
            currentPhase = Phase.Hybrid;
            
            emit PhaseAdvanced(Phase.Hybrid, block.timestamp, totalDeliveries, uniqueDrivers);
        } else if (currentPhase == Phase.Hybrid) {
            require(canAdvanceToFullDAO(), "DecentralizationPhase: Milestones not met for FullDAO");
            currentPhase = Phase.FullDAO;
            
            emit PhaseAdvanced(Phase.FullDAO, block.timestamp, totalDeliveries, uniqueDrivers);
        } else {
            revert("DecentralizationPhase: Already at FullDAO");
        }
    }
    
    /**
     * @notice Records a delivery completion (called by DeliverySystem)
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
    }
    
    /**
     * @notice Records a platform incident (resets stability counter)
     * @param description Description of incident for transparency
     */
    function recordIncident(string memory description) external onlyOwner {
        lastIncidentTime = uint64(block.timestamp);
        
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
            deliveryProgress = (uint256(totalDeliveries) * 100) / PHASE1_MIN_DELIVERIES;
            driverProgress = (uint256(uniqueDrivers) * 100) / PHASE1_MIN_DRIVERS;
            timeProgress = ((block.timestamp - deploymentTime) * 100) / (PHASE1_MIN_DAYS * 1 days);
            canAdvance = canAdvanceToHybrid();
        } else if (currentPhase == Phase.Hybrid) {
            deliveryProgress = (uint256(totalDeliveries) * 100) / PHASE2_MIN_DELIVERIES;
            driverProgress = (uint256(uniqueDrivers) * 100) / PHASE2_MIN_DRIVERS;
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
                PHASE1_MIN_DELIVERIES,
                PHASE1_MIN_DRIVERS,
                PHASE1_MIN_DAYS,
                PHASE1_STABILITY_DAYS
            );
        } else if (currentPhase == Phase.Hybrid) {
            return (
                PHASE2_MIN_DELIVERIES,
                PHASE2_MIN_DRIVERS,
                0, // No time requirement for Phase 2
                PHASE2_STABILITY_DAYS
            );
        } else {
            return (0, 0, 0, 0); // Already at FullDAO
        }
    }
}

