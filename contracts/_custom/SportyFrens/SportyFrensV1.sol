// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract SportyFrensV1 is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable
{
    uint256 public maxPerAddressDuringMint;
    uint256 public amountForDevs;
    uint256 public collectionSize;
    uint256 private _batchSize;
    mapping(address => uint256) public numberMinted;

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 batchSize_,
        uint256 collectionSize_,
        uint256 amountForDevs_
    ) public {
        __ERC721_init(name_, symbol_);
        __ReentrancyGuard_init();
        collectionSize = collectionSize_;
        _batchSize = batchSize_;
        amountForDevs = amountForDevs_;
        require(amountForDevs_ <= collectionSize_, "larger collection size needed");
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function allowlistMint() external payable callerIsUser {
        uint256 price = uint256(allowlistSaleConfig.price);
        require(price != 0, "allowlist sale has not begun yet");
        require(allowlistSaleConfig.allowlist[msg.sender] > 0, "not eligible for allowlist mint");
        require(totalSupply() + 1 <= collectionSize, "reached max supply");
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
        require(totalSupply() + quantity <= collectionSize, "reached max supply");
        require(numberMinted[msg.sender] + quantity <= maxPerAddressDuringMint, "can not mint this many");
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
        require(quantity % _batchSize == 0, "can only mint a multiple of the _batchSize");
        uint256 numChunks = quantity / _batchSize;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(msg.sender, _batchSize);
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {}
}
