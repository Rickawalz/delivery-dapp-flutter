// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeliveryToken
 * @notice RLE (Reliable Logistics Exchange) token for the delivery dApp ecosystem
 * @dev Capped ERC20 with permit signatures and checkpointed voting power.
 *      Holders must delegate, including to themselves, before their balance counts as votes.
 *      Only the owner (BalancedRewardSystem) may mint, and the supply cannot exceed 21 million.
 */
contract DeliveryToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    /// @notice Maximum supply of RLE tokens (21 million, similar to Bitcoin)
    uint256 public constant MAX_SUPPLY = 21e6 * 10**18;
    
    /// @notice Emitted when new tokens are minted
    event TokensMinted(address indexed to, uint256 amount, uint256 totalSupply);
    
    /**
     * @notice Initializes the RLE token
     * @dev Sets token name and symbol, transfers ownership to deployer
     */
    constructor() ERC20("Reliable Logistics Exchange", "RLE") ERC20Permit("Reliable Logistics Exchange") {
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

    /// @dev Keeps vote checkpoints in step with balances.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @dev Mints tokens and records the supply checkpoint.
    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    /// @dev Burns tokens and records the supply checkpoint.
    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
