// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeliveryNFT
 * @dev ERC1155 NFT for delivery receipts and achievement badges
 */
contract DeliveryNFT is ERC1155, Ownable {
    // Token IDs
    uint256 public constant DELIVERY_RECEIPT = 1;
    uint256 public constant ACHIEVEMENT_BADGE = 2;
    
    // Mapping to store metadata URIs
    mapping(uint256 => string) private _tokenURIs;
    
    // Events
    event DeliveryReceiptMinted(address indexed to, uint256 indexed deliveryId, string metadataURI);
    event AchievementBadgeMinted(address indexed to, uint256 badgeType, string metadataURI);
    event MetadataURIUpdated(uint256 indexed tokenId, string newURI);

    constructor() ERC1155("") {
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Mint a delivery receipt NFT
     */
    function mintDeliveryReceipt(
        address to,
        uint256 deliveryId,
        string memory metadataURI
    ) public onlyOwner {
        _mint(to, DELIVERY_RECEIPT, 1, "");
        _tokenURIs[deliveryId] = metadataURI;
        emit DeliveryReceiptMinted(to, deliveryId, metadataURI);
    }

    /**
     * @dev Mint an achievement badge NFT
     */
    function mintAchievementBadge(
        address to,
        uint256 badgeType,
        string memory metadataURI
    ) public onlyOwner {
        _mint(to, ACHIEVEMENT_BADGE, 1, "");
        _tokenURIs[badgeType] = metadataURI;
        emit AchievementBadgeMinted(to, badgeType, metadataURI);
    }

    /**
     * @dev Update metadata URI for a token
     */
    function setTokenURI(uint256 tokenId, string memory newURI) public onlyOwner {
        _tokenURIs[tokenId] = newURI;
        emit MetadataURIUpdated(tokenId, newURI);
    }

    /**
     * @dev Get metadata URI for a token
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return _tokenURIs[tokenId];
    }
} 