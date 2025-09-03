// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RatingSystem
 * @dev Manages ratings for deliveries
 */
contract RatingSystem is ReentrancyGuard {
    // State variables
    struct Rating {
        uint256 rating;
        string comment;
        address reviewer;
        bool exists;
    }
    
    mapping(uint256 => Rating) public ratings;
    uint256 private _ratingCount;
    
    // Constants
    uint256 public constant MIN_RATING = 1;
    uint256 public constant MAX_RATING = 5;
    
    // Events
    event RatingSubmitted(uint256 indexed deliveryId, address indexed reviewer, uint256 rating, string comment);
    event RatingUpdated(uint256 indexed deliveryId, uint256 newRating, string newComment);

    function submitRating(
        uint256 deliveryId,
        uint256 rating,
        string memory comment
    ) external nonReentrant {
        require(rating >= MIN_RATING && rating <= MAX_RATING, "Rating must be between 1 and 5");
        require(!ratings[deliveryId].exists, "Delivery already rated");
        
        // Create rating
        ratings[deliveryId] = Rating({
            rating: rating,
            comment: comment,
            reviewer: msg.sender,
            exists: true
        });
        
        _ratingCount++;
        
        emit RatingSubmitted(deliveryId, msg.sender, rating, comment);
    }

    function getRating(uint256 deliveryId) external view returns (
        uint256 rating,
        string memory comment,
        address reviewer
    ) {
        Rating memory ratingData = ratings[deliveryId];
        if (!ratingData.exists) {
            return (0, "", address(0));
        }
        return (ratingData.rating, ratingData.comment, ratingData.reviewer);
    }

    function getAverageRating() external view returns (uint256) {
        if (_ratingCount == 0) return 0;
        
        uint256 totalRating = 0;
        uint256 count = 0;
        
        // Iterate through all ratings
        for (uint256 i = 1; i <= _ratingCount; i++) {
            if (ratings[i].exists) {
                totalRating += ratings[i].rating;
                count++;
            }
        }
        
        return count > 0 ? totalRating / count : 0;
    }

    function getRatingCount() external view returns (uint256) {
        return _ratingCount;
    }
} 