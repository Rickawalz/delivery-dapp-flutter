// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeliveryToken
 * @dev ERC20 token for the delivery dapp
 */
contract DeliveryToken is ERC20, Ownable {
    // Token parameters
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 million tokens
    uint256 public TRANSFER_DELAY = 1 days;
    
    // Mapping to track last transfer timestamp
    mapping(address => uint256) private _lastTransferTimestamp;
    
    // Events
    event TransferDelayUpdated(uint256 newDelay);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor() ERC20("Delivery Token", "DLV") {
        _transferOwnership(msg.sender);
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Override transfer function to add delay
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(block.timestamp >= _lastTransferTimestamp[msg.sender] + TRANSFER_DELAY, "Transfer delay not met");
        _lastTransferTimestamp[msg.sender] = block.timestamp;
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to add delay
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(block.timestamp >= _lastTransferTimestamp[from] + TRANSFER_DELAY, "Transfer delay not met");
        _lastTransferTimestamp[from] = block.timestamp;
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Mint new tokens (only owner)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burn tokens
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Update transfer delay (only owner)
     */
    function updateTransferDelay(uint256 newDelay) public onlyOwner {
        TRANSFER_DELAY = newDelay;
        emit TransferDelayUpdated(newDelay);
    }
} 