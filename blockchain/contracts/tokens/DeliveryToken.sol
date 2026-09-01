// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeliveryToken
 * @notice RLE (Reliable Logistics Exchange) token for the delivery dApp ecosystem
 * @dev ERC20 token with maximum supply cap of 21 million tokens
 * 
 * Academic Purpose: Demonstrates capped supply token economics similar to Bitcoin's
 * fixed supply model, adapted for gig economy delivery rewards.
 */
contract DeliveryToken is ERC20, Ownable {
    /// @notice Maximum supply of RLE tokens (21 million, similar to Bitcoin)
    uint256 public constant MAX_SUPPLY = 21e6 * 10**18;
    
    /// @notice Emitted when new tokens are minted
    event TokensMinted(address indexed to, uint256 amount, uint256 totalSupply);
    
    /**
     * @notice Initializes the RLE token
     * @dev Sets token name and symbol, transfers ownership to deployer
     */
    constructor() ERC20("Reliable Logistics Exchange", "RLE") {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @notice Mints new tokens to specified address
     * @dev Only owner (reward system) can mint, respects maximum supply cap
     * @param to Address to receive minted tokens
     * @param amount Number of tokens to mint (in wei)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        // ========== COMPREHENSIVE INPUT VALIDATION ==========
        require(to != address(0), "DeliveryToken: Mint to zero address");
        require(to != address(this), "DeliveryToken: Cannot mint to contract");
        require(amount > 0, "DeliveryToken: Amount must be positive");
        require(amount <= 1e6 * 10**18, "DeliveryToken: Amount too large (max 1M per mint)");
        
        // Supply cap validation
        require(totalSupply() + amount <= MAX_SUPPLY, "DeliveryToken: Exceeds maximum supply");
        
        // Overflow protection
        require(totalSupply() + amount >= totalSupply(), "DeliveryToken: Supply overflow");
        
        _mint(to, amount);
        
        emit TokensMinted(to, amount, totalSupply());
    }
    
    /**
     * @notice Returns remaining tokens that can be minted
     * @return Remaining supply available for minting
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
