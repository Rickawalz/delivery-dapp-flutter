// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDeliverySystem
 * @dev Interface for the delivery system contract
 */
interface IDeliverySystem {
    enum DeliveryStatus {
        Pending,
        InProgress,
        Completed,
        Cancelled
    }
    
    struct Delivery {
        uint256 id;
        address customer;
        address courier;
        string pickupAddress;
        string deliveryAddress;
        uint256 price;
        string description;
        DeliveryStatus status;
        uint256 createdAt;
        uint256 completedAt;
    }
    
    event DeliveryCreated(uint256 indexed deliveryId, address indexed customer);
    event DeliveryAccepted(uint256 indexed deliveryId, address indexed courier);
    event DeliveryCompleted(uint256 indexed deliveryId);
    event DeliveryCancelled(uint256 indexed deliveryId);
    
    function createDelivery(
        string memory _pickupAddress,
        string memory _deliveryAddress,
        uint256 _price,
        string memory _description
    ) external returns (uint256);
    
    function acceptDelivery(uint256 _deliveryId) external;
    function completeDelivery(uint256 _deliveryId) external;
    function cancelDelivery(uint256 _deliveryId) external;
    
    function getDelivery(uint256 _deliveryId) external view returns (Delivery memory);
    function getCustomerDeliveries(address _customer) external view returns (Delivery[] memory);
    function getCourierDeliveries(address _courier) external view returns (Delivery[] memory);
} 