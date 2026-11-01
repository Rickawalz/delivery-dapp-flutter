// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeliveryTrackingSystem
 * @notice Provides immutable location tracking and proof of delivery for supply chain transparency
 * @dev Gas-optimized using events for history storage and minimal on-chain state
 * 
 * Academic Purpose: Addresses RQ1 (transparency enhancement) by solving the "Guam container problem"
 * - provides immutable location tracking that prevents items from being lost
 * - enables stakeholders to verify delivery journey at any time
 * - demonstrates blockchain's transparency advantage over centralized systems
 */
contract DeliveryTrackingSystem is Ownable {
    /**
     * @notice Current tracking state for a delivery (optimized for gas)
     * @dev Only stores current location; full history available via events
     */
    struct CurrentTracking {
        bytes32 lastLocationHash;       // Hash of current GPS coordinates (privacy-preserving)
        uint256 lastUpdateTime;          // Timestamp of last update
        bytes32 pickupProofHash;         // IPFS hash of pickup photo/signature
        bytes32 deliveryProofHash;       // IPFS hash of delivery confirmation
        uint8 checkpointCount;           // Total number of checkpoints recorded
        bool disputed;                   // Whether delivery is under dispute
    }
    
    /// @notice Mapping from delivery ID to its current tracking state
    mapping(bytes32 => CurrentTracking) public tracking;
    
    /// @notice Mapping of authorized addresses (drivers/system) per delivery
    mapping(bytes32 => mapping(address => bool)) public authorized;
    
    /// @notice Emitted when a new location checkpoint is added
    event LocationCheckpoint(
        bytes32 indexed deliveryId,
        bytes32 locationHash,
        uint256 timestamp,
        string eventType
    );
    
    /// @notice Emitted when proof of pickup/delivery is submitted
    event ProofSubmitted(
        bytes32 indexed deliveryId,
        bytes32 proofHash,
        string proofType,
        address submitter
    );
    
    /// @notice Emitted when a dispute is raised
    event DisputeRaised(
        bytes32 indexed deliveryId,
        address by,
        string reason,
        uint256 timestamp
    );

    /// @notice Emitted when the owner clears a dispute
    event DisputeResolved(bytes32 indexed deliveryId, uint256 timestamp);
    
    /**
     * @notice Authorizes an address to add checkpoints for a delivery
     * @dev Only owner (DeliverySystem) can authorize drivers for security
     * @param deliveryId Unique delivery identifier
     * @param driver Address authorized to add checkpoints
     */
    function authorizeDriver(bytes32 deliveryId, address driver) external onlyOwner {
        require(deliveryId != bytes32(0), "DeliveryTracking: Invalid delivery ID");
        require(driver != address(0), "DeliveryTracking: Invalid driver address");
        authorized[deliveryId][driver] = true;
    }
    
    /**
     * @notice Revokes authorization for an address
     * @dev Only owner can revoke authorization for security
     * @param deliveryId Unique delivery identifier
     * @param driver Address to revoke authorization from
     */
    function revokeAuthorization(bytes32 deliveryId, address driver) external onlyOwner {
        require(deliveryId != bytes32(0), "DeliveryTracking: Invalid delivery ID");
        require(driver != address(0), "DeliveryTracking: Invalid driver address");
        authorized[deliveryId][driver] = false;
    }
    
    /**
     * @notice Adds a location checkpoint during delivery
     * @dev Uses events for history (gas-efficient), stores only current location
     * @param deliveryId Unique delivery identifier
     * @param locationHash Hash of GPS coordinates (lat,lon hashed for privacy)
     * @param eventType Type of event ("pickup", "in_transit", "delivered")
     */
    function addCheckpoint(
        bytes32 deliveryId,
        bytes32 locationHash,
        string memory eventType
    ) external {
        // ========== COMPREHENSIVE INPUT VALIDATION ==========
        require(deliveryId != bytes32(0), "DeliveryTracking: Invalid delivery ID");
        require(locationHash != bytes32(0), "DeliveryTracking: Invalid location hash");
        require(
            authorized[deliveryId][msg.sender],
            "DeliveryTracking: Not authorized"
        );
        
        // Event type validation
        require(bytes(eventType).length > 0, "DeliveryTracking: Empty event type");
        require(bytes(eventType).length <= 50, "DeliveryTracking: Event type too long");
        
        // Rate limiting (max 1 checkpoint per minute)
        require(
            block.timestamp >= tracking[deliveryId].lastUpdateTime + 60,
            "DeliveryTracking: Rate limit exceeded (1 per minute)"
        );
        
        // Memory caching: Cache timestamp to avoid repeated block.timestamp calls
        uint256 currentTime = block.timestamp;
        
        // Update current state (minimal storage, use cached time)
        tracking[deliveryId].lastLocationHash = locationHash;
        tracking[deliveryId].lastUpdateTime = currentTime;
        tracking[deliveryId].checkpointCount++;
        
        // Emit event for historical record (cheap, queryable off-chain, use cached time)
        emit LocationCheckpoint(deliveryId, locationHash, currentTime, eventType);
    }
    
    /**
     * @notice Submits proof of pickup
     * @dev Stores IPFS hash of photo/signature taken at pickup
     * @param deliveryId Unique delivery identifier
     * @param photoHash IPFS hash of proof document
     */
    function submitPickupProof(bytes32 deliveryId, bytes32 photoHash) external {
        require(
            authorized[deliveryId][msg.sender],
            "DeliveryTracking: Not authorized"
        );
        require(photoHash != bytes32(0), "DeliveryTracking: Invalid proof hash");
        require(
            tracking[deliveryId].pickupProofHash == bytes32(0),
            "DeliveryTracking: Pickup proof already submitted"
        );
        
        tracking[deliveryId].pickupProofHash = photoHash;
        
        emit ProofSubmitted(deliveryId, photoHash, "pickup", msg.sender);
    }
    
    /**
     * @notice Submits proof of delivery completion
     * @dev Stores IPFS hash of delivery confirmation photo/signature
     * @param deliveryId Unique delivery identifier
     * @param photoHash IPFS hash of proof document
     */
    function submitDeliveryProof(bytes32 deliveryId, bytes32 photoHash) external {
        require(
            authorized[deliveryId][msg.sender],
            "DeliveryTracking: Not authorized"
        );
        require(photoHash != bytes32(0), "DeliveryTracking: Invalid proof hash");
        require(
            tracking[deliveryId].deliveryProofHash == bytes32(0),
            "DeliveryTracking: Delivery proof already submitted"
        );
        
        tracking[deliveryId].deliveryProofHash = photoHash;
        
        emit ProofSubmitted(deliveryId, photoHash, "delivery", msg.sender);
    }
    
    /**
     * @notice Raises a dispute for a delivery
     * @dev Can be called by customer or driver if issues arise
     * @param deliveryId Unique delivery identifier
     * @param reason Reason for dispute
     */
    function raiseDispute(bytes32 deliveryId, string memory reason) external {
        require(
            authorized[deliveryId][msg.sender],
            "DeliveryTracking: Not authorized"
        );
        require(!tracking[deliveryId].disputed, "DeliveryTracking: Already disputed");
        
        // Memory caching: Cache timestamp
        uint256 currentTime = block.timestamp;
        
        tracking[deliveryId].disputed = true;
        
        emit DisputeRaised(deliveryId, msg.sender, reason, currentTime);
    }

    /**
     * @notice Clears a dispute so the delivery can be completed
     * @dev Only the owner (SimpleDeliverySystem) may resolve
     * @param deliveryId Unique delivery identifier
     */
    function resolveDispute(bytes32 deliveryId) external onlyOwner {
        require(tracking[deliveryId].disputed, "DeliveryTracking: Not disputed");
        tracking[deliveryId].disputed = false;
        emit DisputeResolved(deliveryId, block.timestamp);
    }

    /**
     * @notice Whether a delivery is currently disputed
     * @param deliveryId Unique delivery identifier
     * @return True when a dispute is open
     */
    function isDisputed(bytes32 deliveryId) public view returns (bool) {
        return tracking[deliveryId].disputed;
    }
    
    /**
     * @notice Gets current location and tracking summary for a delivery
     * @dev Returns on-chain state; full journey available via events
     * @param deliveryId Unique delivery identifier
     * @return location Last known location hash
     * @return lastUpdate Timestamp of last location update
     * @return checkpoints Total number of checkpoints recorded
     * @return pickupProof IPFS hash of pickup proof
     * @return deliveryProof IPFS hash of delivery proof
     * @return disputed Whether delivery is disputed
     */
    function getCurrentLocation(bytes32 deliveryId)
        external
        view
        returns (
            bytes32 location,
            uint256 lastUpdate,
            uint8 checkpoints,
            bytes32 pickupProof,
            bytes32 deliveryProof,
            bool disputed
        )
    {
        CurrentTracking memory t = tracking[deliveryId];
        return (
            t.lastLocationHash,
            t.lastUpdateTime,
            t.checkpointCount,
            t.pickupProofHash,
            t.deliveryProofHash,
            t.disputed
        );
    }
}

