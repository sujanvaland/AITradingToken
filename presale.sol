// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AITradingPresale is Ownable, ReentrancyGuard {
    IERC20 public aitToken;
    uint256 public tokenPrice;
    uint256 public tokensForSale;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    bool public presaleEnded;

    mapping(address => uint256) public tokensPurchased;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event PresaleEnded(uint256 tokensSold);

    constructor(
        address _aitTokenAddress,
        uint256 _tokenPrice,
        uint256 _tokensForSale,
        uint256 _presaleDuration
    ) Ownable(msg.sender) {
        aitToken = IERC20(_aitTokenAddress);
        tokenPrice = _tokenPrice;
        tokensForSale = _tokensForSale;
        presaleStartTime = block.timestamp;
        presaleEndTime = presaleStartTime + _presaleDuration;
    }

    function buyTokens() external payable nonReentrant {
        require(block.timestamp >= presaleStartTime, "Presale has not started yet");
        require(block.timestamp <= presaleEndTime, "Presale has ended");
        require(!presaleEnded, "Presale has already ended");
        require(msg.value > 0, "Invalid amount sent");

        uint256 tokensToBuy = (msg.value * (10**18)) / tokenPrice;
        require(tokensToBuy <= tokensForSale, "Not enough tokens left for sale");

        tokensForSale -= tokensToBuy;
        tokensPurchased[msg.sender] += tokensToBuy;

        require(aitToken.transfer(msg.sender, tokensToBuy), "Token transfer failed");

        emit TokensPurchased(msg.sender, tokensToBuy);

        if (tokensForSale == 0) {
            endPresale();
        }
    }

    function endPresale() public onlyOwner {
        require(block.timestamp > presaleEndTime || tokensForSale == 0, "Presale cannot be ended yet");
        require(!presaleEnded, "Presale has already ended");

        presaleEnded = true;
        uint256 tokensSold = aitToken.balanceOf(address(this));
        require(aitToken.transfer(owner(), tokensSold), "Failed to return unsold tokens");

        emit PresaleEnded(tokensSold);
    }

    function withdrawFunds() external onlyOwner {
        require(presaleEnded, "Presale has not ended yet");
        payable(owner()).transfer(address(this).balance);
    }

    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Invalid token price");
        tokenPrice = _newPrice;
    }

    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }
}

