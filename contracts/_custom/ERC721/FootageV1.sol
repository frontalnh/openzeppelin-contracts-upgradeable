// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./ERC721AUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FootageV1 is OwnableUpgradeable, ERC721A, ReentrancyGuardUpgradeable {
    uint256 public maxPerAddressDuringMint;
    uint256 public amountForDevs;
    uint256 public amountForAuctionAndDev;

    struct PreSaleConfig {
        bool open;
        uint32 startTime;
        uint32 endTime;
        uint256 price;
        uint256 limit;
    }

    struct PublicSaleConfig {
        bool open;
        uint32 publicSaleKey;
        uint32 startTime;
        uint32 endTime;
        uint64 price;
        uint256 limit;
    }

    struct AllowlistSaleConfig {
        bool open;
        uint256 price; // mint price for allow list accounts
        uint32 startTime;
        uint32 endTime;
        mapping(address => uint256) allowlist;
    }

    PreSaleConfig public preSaleConfig;
    PublicSaleConfig public publicSaleConfig;
    AllowlistSaleConfig public allowlistSaleConfig;

    function initialize(
        uint256 _maxBatchSize_,
        uint256 _collectionSize_,
        uint256 amountForAuctionAndDev_,
        uint256 amountForDevs_
    ) public {
        __ERC721AUpgradable_init("Azuki", "AZUKI", _maxBatchSize_, _collectionSize_);
        __ReentrancyGuard_init();
        maxPerAddressDuringMint = _maxBatchSize_;
        amountForAuctionAndDev = amountForAuctionAndDev_;
        amountForDevs = amountForDevs_;
        require(amountForAuctionAndDev_ <= _collectionSize_, "larger collection size needed");
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function allowlistMint() external payable callerIsUser {
        uint256 price = uint256(allowlistSaleConfig.price);
        require(price != 0, "allowlist sale has not begun yet");
        require(allowlistSaleConfig.allowlist[msg.sender] > 0, "not eligible for allowlist mint");
        require(totalSupply() + 1 <= _collectionSize, "reached max supply");
        allowlistSaleConfig.allowlist[msg.sender]--;
        _safeMint(msg.sender, 1);
        _refundIfOver(price);
    }

    function publicSaleMint(uint256 quantity, uint256 callerPublicSaleKey) external payable callerIsUser {
        PublicSaleConfig memory config = publicSaleConfig;
        uint256 publicSaleKey = uint256(config.publicSaleKey);
        uint256 publicPrice = uint256(config.price);
        uint256 publicSaleStartTime = uint256(config.startTime);
        require(publicSaleKey == callerPublicSaleKey, "called with incorrect public sale key");

        require(isPublicSaleOn(publicPrice, publicSaleKey, publicSaleStartTime), "public sale has not begun yet");
        require(totalSupply() + quantity <= _collectionSize, "reached max supply");
        require(numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint, "can not mint this many");
        _safeMint(msg.sender, quantity);
        _refundIfOver(publicPrice * quantity);
    }

    function _refundIfOver(uint256 price) private {
        require(msg.value >= price, "Need to send more ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function isPublicSaleOn(
        uint256 publicPriceWei,
        uint256 publicSaleKey,
        uint256 publicSaleStartTime
    ) public view returns (bool) {
        return publicPriceWei != 0 && publicSaleKey != 0 && block.timestamp >= publicSaleStartTime;
    }

    function setPublicSaleKey(uint32 key) external onlyOwner {
        publicSaleConfig.publicSaleKey = key;
    }

    function seedAllowlist(address[] memory addresses, uint256[] memory numSlots) external onlyOwner {
        require(addresses.length == numSlots.length, "addresses does not match numSlots length");
        for (uint256 i = 0; i < addresses.length; i++) {
            allowlistSaleConfig.allowlist[addresses[i]] = numSlots[i];
        }
    }

    // For marketing etc.
    function devMint(uint256 quantity) external onlyOwner {
        require(totalSupply() + quantity <= amountForDevs, "too many already minted before dev mint");
        require(quantity % _maxBatchSize == 0, "can only mint a multiple of the _maxBatchSize");
        uint256 numChunks = quantity / _maxBatchSize;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(msg.sender, _maxBatchSize);
        }
    }

    // // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        _setOwnersExplicit(quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId) external view returns (TokenOwnership memory) {
        return _ownershipOf(tokenId);
    }
}
