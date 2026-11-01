// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../tokens/DeliveryToken.sol";

/**
 * @title BalancedRewardSystem
 * @notice Multi-factor reward calculation system preventing gaming through interdependent metrics
 * @dev PRIMARY ACADEMIC CONTRIBUTION - Novel balanced scoring algorithm
 * 
 * Research Contribution:
 * Unlike single-factor reward systems (e.g., Uber's volume-only model), this contract implements
 * a multi-factor balanced approach where rewards depend on:
 * 1. Volume (baseline participation)
 * 2. Distance (with diminishing returns to prevent farming)
 * 3. Rating (quality incentive)
 * 4. Diversity (variety encouragement)
 * 
 * This interdependence prevents gaming: optimizing one factor alone provides minimal benefit,
 * encouraging holistic quality service over exploitation.
 * 
 * Additionally implements adaptive difficulty adjustment (weekly) to maintain sustainable
 * token distribution regardless of network scale (addresses RQ3: scalability challenge).
 */
contract BalancedRewardSystem is Ownable, ReentrancyGuard {
    DeliveryToken public token;
    
    // ============ POINT CALCULATION CONSTANTS ============
    
    /// @notice Points awarded per delivery completion (volume factor)
    uint256 public constant POINTS_PER_DELIVERY = 100;
    
    /// @notice Points awarded per kilometer driven (distance factor)
    uint256 public constant POINTS_PER_KILOMETER = 10;
    
    /// @notice Points awarded per rating star (quality factor)
    uint256 public constant POINTS_PER_STAR = 20;
    
    /// @notice Maximum theoretical points per delivery
    uint256 public constant MAX_POINTS = 600;
    
    // ============ ANTI-GAMING LIMITS ============
    
    /// @notice Minimum distance to earn rewards (prevents spam deliveries)
    uint256 public constant MIN_DISTANCE = 500; // 500 meters
    
    /// @notice Maximum distance for bonus calculation (prevents unrealistic claims)
    uint256 public constant MAX_DISTANCE_REWARD = 30000; // 30 kilometers
    
    /// @notice Minimum time between deliveries (prevents bot automation)
    uint256 public constant MIN_TIME_BETWEEN = 10 minutes;
    
    /// @notice Maximum deliveries per day per driver (prevents exploitation)
    uint256 public constant MAX_DAILY_DELIVERIES = 50;
    
    // ============ DISTANCE TIERS (Diminishing Returns) ============
    
    /// @notice Short distance tier threshold (full efficiency)
    uint256 public constant DISTANCE_TIER_1 = 5000; // 5km: 100% points
    
    /// @notice Medium distance tier threshold (90% efficiency)
    uint256 public constant DISTANCE_TIER_2 = 15000; // 15km: 90% points
    
    /// @notice Long distance tier threshold (80% efficiency)
    uint256 public constant DISTANCE_TIER_3 = 30000; // 30km: 80% points
    // Above 30km: 70% efficiency (prevents distance farming)
    
    // ============ ADAPTIVE DIFFICULTY PARAMETERS ============
    
    /// @notice Target daily deliveries for network (used for adaptive adjustment)
    uint256 public constant TARGET_DAILY_DELIVERIES = 1000;
    
    /// @notice Adjustment window (how often to check and adjust rate)
    uint256 public constant ADJUSTMENT_WINDOW = 7 days;
    
    /// @notice Current token conversion rate (1 RLE per 100 points initially)
    uint256 public currentTokenRate = 1 * 10**18;
    
    /// @notice Last time adaptive adjustment was performed
    uint256 public lastAdjustmentTime;
    
    /// @notice Deliveries completed at last adjustment
    uint256 public lastAdjustmentDeliveries;
    
    /// @notice Total deliveries completed globally
    uint256 public totalDeliveriesCompleted;
    
    // ============ DRIVER STATISTICS (Gas-Optimized with Packed Struct) ============
    
    /**
     * @notice Driver statistics tracking
     * @dev Packed struct saves ~75% gas compared to using all uint256
     * Uses smaller uints sufficient for the ranges needed
     */
    struct DriverStats {
        uint64 lastDeliveryTime;     // Timestamp of last delivery (sufficient until year 2554)
        uint16 deliveriesToday;      // Deliveries today (max 65k, way more than limit of 50)
        uint64 lastDayReset;         // When daily counter was last reset
        uint32 totalDeliveries;      // Total deliveries (max 4 billion, sufficient)
        uint128 totalEarned;         // Total RLE earned (max ~340 trillion tokens, sufficient)
    }
    
    /// @notice Mapping from driver address to their statistics
    mapping(address => DriverStats) public drivers;
    
    // ============ DIVERSITY TRACKING (Gas-Optimized) ============
    
    /**
     * @notice Tracks delivery type diversity for bonus calculation
     * @dev Resets daily; encourages varied delivery distances
     */
    struct DiversityTracker {
        uint8 shortDeliveries;       // Count of short deliveries today (<5km)
        uint8 mediumDeliveries;      // Count of medium deliveries today (5-15km)
        uint8 longDeliveries;        // Count of long deliveries today (15km+)
        uint64 lastReset;            // When diversity was last reset
    }
    
    /// @notice Mapping from driver address to diversity tracking
    mapping(address => DiversityTracker) public diversity;
    
    // ============ EVENTS ============
    
    /// @notice Emitted when a reward is calculated and minted
    event RewardCalculated(
        address indexed driver,
        uint256 distanceMeters,
        uint8 rating,
        uint256 volumePoints,
        uint256 distancePoints,
        uint256 ratingPoints,
        uint256 diversityBonus,
        uint256 totalPoints,
        uint256 tokenReward
    );
    
    /// @notice Emitted when adaptive rate is adjusted
    event RateAdjusted(
        uint256 newRate,
        uint256 oldRate,
        uint256 currentVelocity,
        string reason
    );
    
    /**
     * @notice Initializes the reward system
     * @param _token Address of the DeliveryToken contract
     */
    constructor(address _token) {
        require(_token != address(0), "BalancedReward: Invalid token address");
        token = DeliveryToken(_token);
        _transferOwnership(msg.sender);
        lastAdjustmentTime = block.timestamp;
    }
    
    /**
     * @notice Processes reward for completed delivery (MAIN FUNCTION)
     * @dev Implements balanced scoring algorithm and adaptive difficulty
     * 
     * Academic Note: This function demonstrates the core research contribution:
     * multi-factor balancing that prevents gaming while maintaining fairness
     * 
     * @param driver Address of the driver completing the delivery
     * @param distanceMeters Distance traveled in meters
     * @param rating Customer rating (1-5 stars)
     * @return tokenReward Amount of RLE tokens minted to driver
     */
    function processReward(
        address driver,
        uint256 distanceMeters,
        uint8 rating
    ) external onlyOwner nonReentrant returns (uint256) {
        // ========== COMPREHENSIVE INPUT VALIDATION ==========
        
        // Address validation
        require(driver != address(0), "BalancedReward: Invalid driver address");
        require(driver != address(this), "BalancedReward: Cannot reward contract");
        
        // Rating validation (1-5 stars)
        require(rating >= 1 && rating <= 5, "BalancedReward: Rating must be 1-5");
        
        // Distance validation (reasonable bounds)
        require(distanceMeters >= MIN_DISTANCE, "BalancedReward: Distance too short");
        require(distanceMeters <= 1000_000, "BalancedReward: Distance too long (max 1000km)");
        
        // Overflow protection
        require(distanceMeters < type(uint32).max, "BalancedReward: Distance overflow");
        
        // Token supply validation
        require(token.totalSupply() < token.MAX_SUPPLY(), "BalancedReward: Max supply reached");
        
        // Memory caching: Load once, use multiple times
        DriverStats storage stats = drivers[driver];
        DiversityTracker storage div = diversity[driver];
        
        // Cache frequently used values to avoid repeated storage reads
        uint256 currentTime = block.timestamp;
        uint256 cachedCurrentRate = currentTokenRate;
        
        // Reset daily counters if new day (use cached time)
        if (currentTime >= stats.lastDayReset + 1 days) {
            stats.deliveriesToday = 0;
            stats.lastDayReset = uint64(currentTime);
            
            // Reset diversity tracker
            div.shortDeliveries = 0;
            div.mediumDeliveries = 0;
            div.longDeliveries = 0;
            div.lastReset = uint64(currentTime);
        }
        
        // Anti-gaming enforcement (use cached time)
        require(
            currentTime >= stats.lastDeliveryTime + MIN_TIME_BETWEEN,
            "BalancedReward: Must wait 10 minutes between deliveries"
        );
        require(
            stats.deliveriesToday < MAX_DAILY_DELIVERIES,
            "BalancedReward: Daily limit of 50 deliveries reached"
        );
        
        // Check and perform adaptive adjustment if needed
        checkAndAdjustRate();
        
        // ========== CALCULATE BALANCED REWARD ==========
        
        // Factor 1: Volume points (baseline for completing delivery)
        uint256 volumePoints = POINTS_PER_DELIVERY;
        
        // Factor 2: Distance points (with diminishing returns)
        uint256 distancePoints = calculateDistancePoints(distanceMeters);
        
        // Factor 3: Rating points (quality incentive)
        uint256 ratingPoints = uint256(rating) * POINTS_PER_STAR;
        
        // Factor 4: Diversity bonus (variety encouragement)
        uint256 diversityBonus = calculateDiversityBonus(driver, distanceMeters);
        
        // Total balanced points
        uint256 totalPoints = volumePoints + distancePoints + ratingPoints + diversityBonus;
        
        // Convert points to tokens using cached rate (gas optimization)
        uint256 tokenReward = (totalPoints * cachedCurrentRate) / 100;
        
        // Update driver statistics (use cached time)
        stats.lastDeliveryTime = uint64(currentTime);
        stats.deliveriesToday++;
        stats.totalDeliveries++;
        stats.totalEarned += uint128(tokenReward);
        
        // Update diversity tracker
        updateDiversityTracker(driver, distanceMeters);
        
        // Update global counter
        totalDeliveriesCompleted++;
        
        // Mint reward tokens
        token.mint(driver, tokenReward);
        
        // Emit detailed breakdown for transparency
        emit RewardCalculated(
            driver,
            distanceMeters,
            rating,
            volumePoints,
            distancePoints,
            ratingPoints,
            diversityBonus,
            totalPoints,
            tokenReward
        );
        
        return tokenReward;
    }
    
    /**
     * @notice Calculates distance points with diminishing returns
     * @dev Implements tiered efficiency to prevent distance farming
     * 
     * Academic Rationale: Diminishing returns prevent drivers from optimizing
     * solely for distance (taking only long routes), encouraging balanced approach
     * 
     * @param distanceMeters Distance in meters
     * @return Points earned from distance factor
     */
    function calculateDistancePoints(uint256 distanceMeters) 
        public 
        pure 
        returns (uint256) 
    {
        if (distanceMeters < MIN_DISTANCE) {
            return 0;
        }
        
        // Cap at maximum distance for reward calculation
        uint256 effectiveDistance = distanceMeters;
        if (effectiveDistance > MAX_DISTANCE_REWARD) {
            effectiveDistance = MAX_DISTANCE_REWARD;
        }
        
        // Convert to kilometers
        uint256 distanceKm = effectiveDistance / 1000;
        
        // Base points calculation
        uint256 basePoints = distanceKm * POINTS_PER_KILOMETER;
        
        // Apply diminishing returns based on tier
        if (distanceMeters <= DISTANCE_TIER_1) {
            return basePoints; // 0-5km: 100% efficiency
        } else if (distanceMeters <= DISTANCE_TIER_2) {
            return (basePoints * 90) / 100; // 5-15km: 90% efficiency
        } else if (distanceMeters <= DISTANCE_TIER_3) {
            return (basePoints * 80) / 100; // 15-30km: 80% efficiency
        } else {
            return (basePoints * 70) / 100; // 30km+: 70% efficiency
        }
    }
    
    /**
     * @notice Calculates diversity bonus for varied delivery distances
     * @dev Encourages drivers to accept mix of short/medium/long deliveries
     * 
     * Academic Rationale: Prevents strategy of only accepting one delivery type
     * (e.g., only short deliveries next door), promotes network efficiency
     * 
     * @param driver Driver address
     * @param distanceMeters Current delivery distance
     * @return Bonus points for diversity (0, 25, or 50)
     */
    function calculateDiversityBonus(address driver, uint256 distanceMeters)
        internal
        view
        returns (uint256)
    {
        // Memory caching: Load diversity tracker once
        DiversityTracker memory div = diversity[driver];
        uint256 currentTime = block.timestamp;
        
        // If day just reset, no bonus yet (use cached time)
        if (currentTime >= div.lastReset + 1 days) {
            return 0;
        }
        
        // Count delivery types including current delivery
        uint256 typesCompleted = 0;
        
        if (div.shortDeliveries > 0 || distanceMeters < DISTANCE_TIER_1) {
            typesCompleted++;
        }
        if (div.mediumDeliveries > 0 || 
            (distanceMeters >= DISTANCE_TIER_1 && distanceMeters < DISTANCE_TIER_2)) {
            typesCompleted++;
        }
        if (div.longDeliveries > 0 || distanceMeters >= DISTANCE_TIER_2) {
            typesCompleted++;
        }
        
        // Award bonus based on variety
        if (typesCompleted == 3) {
            return 50; // All three types: maximum bonus
        } else if (typesCompleted == 2) {
            return 25; // Two types: moderate bonus
        }
        
        return 0; // Single type: no bonus
    }
    
    /**
     * @notice Updates diversity tracker after delivery completion
     * @param driver Driver address
     * @param distanceMeters Distance of completed delivery
     */
    function updateDiversityTracker(address driver, uint256 distanceMeters) internal {
        DiversityTracker storage div = diversity[driver];
        
        if (distanceMeters < DISTANCE_TIER_1) {
            div.shortDeliveries++;
        } else if (distanceMeters < DISTANCE_TIER_2) {
            div.mediumDeliveries++;
        } else {
            div.longDeliveries++;
        }
    }
    
    /**
     * @notice Adaptive difficulty adjustment (Bitcoin-inspired)
     * @dev Adjusts token conversion rate weekly based on network velocity
     * 
     * Academic Purpose: Addresses RQ3 (scalability) by maintaining sustainable
     * token distribution at any network scale. Prevents rapid token exhaustion
     * during viral growth or excessive rewards during slow periods.
     * 
     * Adjustment Logic:
     * - If network velocity > 2x target: Reduce rate by 10% (slow token minting)
     * - If network velocity < 0.5x target: Increase rate by 10% (encourage participation)
     * - Otherwise: No change (system stable)
     */
    function checkAndAdjustRate() internal {
        // Only adjust every ADJUSTMENT_WINDOW (weekly)
        if (block.timestamp < lastAdjustmentTime + ADJUSTMENT_WINDOW) {
            return;
        }
        
        // Calculate network velocity (deliveries per day)
        uint256 deliveriesSinceLastAdjustment = totalDeliveriesCompleted - lastAdjustmentDeliveries;
        uint256 timeElapsed = block.timestamp - lastAdjustmentTime;
        uint256 dailyVelocity = (deliveriesSinceLastAdjustment * 1 days) / timeElapsed;
        
        uint256 oldRate = currentTokenRate;
        
        // Adjust rate if velocity deviates significantly from target
        if (dailyVelocity > TARGET_DAILY_DELIVERIES * 2) {
            // Network too fast: reduce rewards by 10%
            currentTokenRate = (currentTokenRate * 90) / 100;
            
            emit RateAdjusted(
                currentTokenRate,
                oldRate,
                dailyVelocity,
                "Network velocity too high"
            );
        } else if (dailyVelocity < TARGET_DAILY_DELIVERIES / 2) {
            // Network too slow: increase rewards by 10%
            currentTokenRate = (currentTokenRate * 110) / 100;
            
            emit RateAdjusted(
                currentTokenRate,
                oldRate,
                dailyVelocity,
                "Network velocity too low"
            );
        }
        // else: velocity is acceptable, no adjustment needed
        
        // Update adjustment tracking
        lastAdjustmentTime = block.timestamp;
        lastAdjustmentDeliveries = totalDeliveriesCompleted;
    }
    
    /**
     * @notice Previews reward for hypothetical delivery (gas-free view function)
     * @dev Used by frontend to show drivers expected rewards before accepting delivery
     * 
     * Academic Value: Demonstrates transparency - drivers know exactly what they'll earn
     * before committing to delivery, unlike opaque algorithms in traditional platforms
     * 
     * @param driver Driver address (for diversity calculation)
     * @param distanceMeters Hypothetical distance
     * @param rating Expected rating
     * @return volumePoints Points from volume factor
     * @return distancePoints Points from distance factor
     * @return ratingPoints Points from rating factor
     * @return diversityBonus Bonus points from diversity factor
     * @return totalPoints Total points calculated
     * @return tokenReward Expected token reward
     */
    function previewReward(
        address driver,
        uint256 distanceMeters,
        uint8 rating
    )
        external
        view
        returns (
            uint256 volumePoints,
            uint256 distancePoints,
            uint256 ratingPoints,
            uint256 diversityBonus,
            uint256 totalPoints,
            uint256 tokenReward
        )
    {
        // ========== INPUT VALIDATION FOR PREVIEW ==========
        require(driver != address(0), "BalancedReward: Invalid driver address");
        require(rating >= 1 && rating <= 5, "BalancedReward: Rating must be 1-5");
        require(distanceMeters >= MIN_DISTANCE, "BalancedReward: Distance too short");
        require(distanceMeters <= 1000_000, "BalancedReward: Distance too long");
        
        volumePoints = POINTS_PER_DELIVERY;
        distancePoints = calculateDistancePoints(distanceMeters);
        ratingPoints = uint256(rating) * POINTS_PER_STAR;
        diversityBonus = calculateDiversityBonus(driver, distanceMeters);
        
        totalPoints = volumePoints + distancePoints + ratingPoints + diversityBonus;
        tokenReward = (totalPoints * currentTokenRate) / 100;
        
        return (volumePoints, distancePoints, ratingPoints, diversityBonus, totalPoints, tokenReward);
    }
    
    /**
     * @notice Gets comprehensive statistics for a driver
     * @param driver Driver address
     * @return lastDelivery Timestamp of last delivery
     * @return deliveriesToday Number of deliveries completed today
     * @return totalDeliveries Total lifetime deliveries
     * @return totalEarned Total RLE tokens earned
     * @return shortCount Short deliveries today
     * @return mediumCount Medium deliveries today
     * @return longCount Long deliveries today
     */
    function getDriverStats(address driver)
        external
        view
        returns (
            uint256 lastDelivery,
            uint256 deliveriesToday,
            uint256 totalDeliveries,
            uint256 totalEarned,
            uint256 shortCount,
            uint256 mediumCount,
            uint256 longCount
        )
    {
        DriverStats memory stats = drivers[driver];
        DiversityTracker memory div = diversity[driver];
        
        return (
            stats.lastDeliveryTime,
            stats.deliveriesToday,
            stats.totalDeliveries,
            stats.totalEarned,
            div.shortDeliveries,
            div.mediumDeliveries,
            div.longDeliveries
        );
    }
    
    /**
     * @notice Gets current network statistics for adaptive system
     * @return rate Current token conversion rate
     * @return deliveries Total deliveries completed
     * @return lastAdjust Last adjustment timestamp
     * @return targetDaily Target daily delivery count
     */
    function getNetworkStats()
        external
        view
        returns (
            uint256 rate,
            uint256 deliveries,
            uint256 lastAdjust,
            uint256 targetDaily
        )
    {
        return (
            currentTokenRate,
            totalDeliveriesCompleted,
            lastAdjustmentTime,
            TARGET_DAILY_DELIVERIES
        );
    }
    
    /**
     * @notice Manual rate adjustment (emergency override, Phase 1 only)
     * @dev Allows founder to override adaptive algorithm if it malfunctions
     * @param newRate New token conversion rate
     */
    function manualAdjustRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "BalancedReward: Rate must be positive");
        require(newRate <= 10 * 10**18, "BalancedReward: Rate too high");
        
        uint256 oldRate = currentTokenRate;
        currentTokenRate = newRate;
        
        emit RateAdjusted(newRate, oldRate, 0, "Manual adjustment");
    }

    /**
     * @notice Governance rate adjustment after Bootstrap
     * @dev Same bounds as manualAdjustRate. Caller must be the owner (SimpleDeliverySystem).
     * @param newRate New token conversion rate
     */
    function setTokenRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "BalancedReward: Rate must be positive");
        require(newRate <= 10 * 10**18, "BalancedReward: Rate too high");

        uint256 oldRate = currentTokenRate;
        currentTokenRate = newRate;

        emit RateAdjusted(newRate, oldRate, 0, "Governance adjustment");
    }
}

