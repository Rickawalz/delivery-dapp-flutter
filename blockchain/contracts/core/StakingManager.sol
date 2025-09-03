// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../tokens/DeliveryToken.sol";

/**
 * @title StakingManager
 * @dev Manages driver staking and rewards
 */
contract StakingManager is Ownable, ReentrancyGuard {
    // State variables
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 lastRewardTime;
    }
    
    mapping(address => Stake) public stakes;
    mapping(address => uint256) public rewards;
    
    // Contract references
    DeliveryToken public deliveryToken;
    
    // Constants
    uint256 public constant MINIMUM_STAKE = 100 * 10**18; // 100 tokens
    uint256 public constant MINIMUM_LOCK_PERIOD = 30 days;
    uint256 public constant REWARD_RATE = 5; // 5% annual reward rate
    
    // Events
    event Staked(address indexed driver, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed driver, uint256 amount);
    event RewardPaid(address indexed driver, uint256 reward);
    event StakeSlashed(address indexed driver, uint256 amount, string reason);

    constructor(address _deliveryToken) {
        _transferOwnership(msg.sender);
        deliveryToken = DeliveryToken(_deliveryToken);
    }

    function stake(uint256 amount, uint256 lockPeriod) external nonReentrant {
        require(amount >= MINIMUM_STAKE, "Below minimum stake");
        require(lockPeriod >= MINIMUM_LOCK_PERIOD, "Lock period too short");
        require(stakes[msg.sender].amount == 0, "Already staked");
        
        // Transfer tokens to contract
        deliveryToken.transferFrom(msg.sender, address(this), amount);
        
        // Create stake
        stakes[msg.sender] = Stake({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            lastRewardTime: block.timestamp
        });
        
        emit Staked(msg.sender, amount, lockPeriod);
    }

    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");
        require(
            block.timestamp >= userStake.startTime + userStake.lockPeriod,
            "Lock period not ended"
        );
        
        // Calculate and pay rewards
        uint256 reward = calculateReward(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = reward;
            emit RewardPaid(msg.sender, reward);
        }
        
        // Return staked tokens
        uint256 amount = userStake.amount;
        delete stakes[msg.sender];
        deliveryToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }

    function calculateReward(address driver) public view returns (uint256) {
        Stake storage userStake = stakes[driver];
        if (userStake.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userStake.lastRewardTime;
        return (userStake.amount * REWARD_RATE * timeElapsed) / (365 days * 100);
    }

    function slashStake(address driver, uint256 amount, string memory reason) external onlyOwner {
        Stake storage userStake = stakes[driver];
        require(userStake.amount >= amount, "Insufficient stake");
        
        userStake.amount -= amount;
        deliveryToken.transfer(owner(), amount);
        
        emit StakeSlashed(driver, amount, reason);
    }

    function getStakeInfo(address driver) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 lockPeriod,
        uint256 lastRewardTime
    ) {
        Stake storage userStake = stakes[driver];
        return (
            userStake.amount,
            userStake.startTime,
            userStake.lockPeriod,
            userStake.lastRewardTime
        );
    }
} 