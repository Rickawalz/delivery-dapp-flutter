// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeliverySystem is ReentrancyGuard, Ownable {
    IERC20 public deliveryToken;
    
    struct Delivery {
        address sender;
        address receiver;
        uint256 amount;
        bool completed;
        uint256 timestamp;
    }
    
    mapping(bytes32 => Delivery) public deliveries;
    
    event DeliveryCreated(bytes32 indexed deliveryId, address indexed sender, address indexed receiver, uint256 amount);
    event DeliveryCompleted(bytes32 indexed deliveryId);
    
    constructor(address _deliveryToken) {
        require(_deliveryToken != address(0), "Invalid token address");
        deliveryToken = IERC20(_deliveryToken);
    }
    
    function createDelivery(address _receiver, uint256 _amount) external nonReentrant {
        require(_receiver != address(0), "Invalid receiver address");
        require(_amount > 0, "Amount must be greater than 0");
        
        bytes32 deliveryId = keccak256(abi.encodePacked(msg.sender, _receiver, _amount, block.timestamp));
        
        require(deliveries[deliveryId].timestamp == 0, "Delivery already exists");
        
        require(deliveryToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        deliveries[deliveryId] = Delivery({
            sender: msg.sender,
            receiver: _receiver,
            amount: _amount,
            completed: false,
            timestamp: block.timestamp
        });
        
        emit DeliveryCreated(deliveryId, msg.sender, _receiver, _amount);
    }
    
    function completeDelivery(bytes32 _deliveryId) external nonReentrant {
        Delivery storage delivery = deliveries[_deliveryId];
        require(delivery.timestamp > 0, "Delivery does not exist");
        require(!delivery.completed, "Delivery already completed");
        require(msg.sender == delivery.receiver, "Only receiver can complete delivery");
        
        delivery.completed = true;
        require(deliveryToken.transfer(delivery.receiver, delivery.amount), "Transfer failed");
        
        emit DeliveryCompleted(_deliveryId);
    }
    
    function getDelivery(bytes32 _deliveryId) external view returns (
        address sender,
        address receiver,
        uint256 amount,
        bool completed,
        uint256 timestamp
    ) {
        Delivery storage delivery = deliveries[_deliveryId];
        return (
            delivery.sender,
            delivery.receiver,
            delivery.amount,
            delivery.completed,
            delivery.timestamp
        );
    }
} 