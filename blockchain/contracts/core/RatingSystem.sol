// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    
    // Gas optimization: Maintain running totals instead of O(n) loops
    uint256 private _totalRatingSum;
    uint256 private _validRatingCount;
    
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
        // ========== COMPREHENSIVE INPUT VALIDATION ==========
        require(deliveryId > 0, "RatingSystem: Invalid delivery ID");
        require(rating >= MIN_RATING && rating <= MAX_RATING, "Rating must be between 1 and 5");
        require(!ratings[deliveryId].exists, "Delivery already rated");
        
        // Comment validation
        require(bytes(comment).length <= 500, "RatingSystem: Comment too long (max 500 chars)");
        
        // Overflow protection
        require(_ratingCount < type(uint32).max, "RatingSystem: Too many ratings");
        require(_totalRatingSum + rating <= type(uint128).max, "RatingSystem: Rating sum overflow");
        
        // Create rating
        ratings[deliveryId] = Rating({
            rating: rating,
            comment: comment,
            reviewer: msg.sender,
            exists: true
        });
        
        // Update running totals for O(1) average calculation
        _ratingCount++;
        _totalRatingSum += rating;
        _validRatingCount++;
        
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
        // O(1) calculation using pre-computed totals
        if (_validRatingCount == 0) return 0;
        return _totalRatingSum / _validRatingCount;
    }

    function updateRating(
        uint256 deliveryId,
        uint256 newRating,
        string memory newComment
    ) external nonReentrant {
        // ========== COMPREHENSIVE INPUT VALIDATION ==========
        require(deliveryId > 0, "RatingSystem: Invalid delivery ID");
        require(newRating >= MIN_RATING && newRating <= MAX_RATING, "Rating must be between 1 and 5");
        require(ratings[deliveryId].exists, "Rating does not exist");
        require(ratings[deliveryId].reviewer == msg.sender, "Only reviewer can update rating");
        
        // Comment validation
        require(bytes(newComment).length <= 500, "RatingSystem: Comment too long (max 500 chars)");
        
        // Overflow protection
        require(_totalRatingSum - ratings[deliveryId].rating + newRating <= type(uint128).max, "RatingSystem: Rating sum overflow");
        
        // Update running totals
        uint256 oldRating = ratings[deliveryId].rating;
        _totalRatingSum = _totalRatingSum - oldRating + newRating;
        
        // Update rating
        ratings[deliveryId].rating = newRating;
        ratings[deliveryId].comment = newComment;
        
        emit RatingUpdated(deliveryId, newRating, newComment);
    }

    function getRatingCount() external view returns (uint256) {
        return _ratingCount;
    }
    
    function getValidRatingCount() external view returns (uint256) {
        return _validRatingCount;
    }
    
    function getTotalRatingSum() external view returns (uint256) {
        return _totalRatingSum;
    }
} 