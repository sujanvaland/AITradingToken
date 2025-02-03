// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AITradingPresale is Ownable, ReentrancyGuard {
    IERC20 public immutable aitToken;
    IERC20 public usdtToken;
    IERC20 public usdcToken;
    address public wethAddress; // Wrapped ETH address on BSC

    uint256 public tokenPriceInUSDT; // Price of 1 AIT token in USDT
    uint256 public tokensForSale;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    bool public presaleEnded;

    uint256 public totalTokensSold;
    mapping(address => uint256) public tokensPurchased;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event PresaleEnded(uint256 totalTokensSold);
    event FundsWithdrawn(uint256 amount);

    constructor(
        address _aitTokenAddress,
        address _usdtTokenAddress,
        address _usdcTokenAddress,
        address _wethAddress,
        uint256 _tokenPriceInUSDT,
        uint256 _tokensForSale,
        uint256 _presaleDuration
    ) Ownable(msg.sender) {
        aitToken = IERC20(_aitTokenAddress);
        usdtToken = IERC20(_usdtTokenAddress);
        usdcToken = IERC20(_usdcTokenAddress);
        wethAddress = _wethAddress;
        tokenPriceInUSDT = _tokenPriceInUSDT;
        tokensForSale = _tokensForSale;
        presaleStartTime = block.timestamp;
        presaleEndTime = presaleStartTime + _presaleDuration;
    }

    function buyTokens(address token, uint256 amount) external nonReentrant {
        require(block.timestamp >= presaleStartTime, "Presale has not started yet");
        require(block.timestamp <= presaleEndTime, "Presale has ended");
        require(!presaleEnded, "Presale has already ended");
        require(amount > 0, "Amount must be greater than 0");

        uint256 tokensToBuy = 0;

        // Handle different token payments
        if (token == address(usdtToken)) {
            tokensToBuy = (amount * 10**18) / tokenPriceInUSDT; // Price in USDT
            require(usdtToken.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        } else if (token == address(usdcToken)) {
            tokensToBuy = (amount * 10**18) / tokenPriceInUSDT; // Price in USDC (same rate as USDT for simplicity)
            require(usdcToken.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        } else if (token == wethAddress) {
            // If paying with Wrapped ETH (WETH)
            uint256 wethAmount = amount; // Assuming user sends amount in ETH (converted to WETH)
            uint256 ethInUSDT = getETHInUSDT(wethAmount); // Get equivalent value in USDT
            tokensToBuy = (ethInUSDT * 10**18) / tokenPriceInUSDT; // Convert to AIT tokens
            require(IERC20(wethAddress).transferFrom(msg.sender, address(this), wethAmount), "WETH transfer failed");
        } else {
            revert("Unsupported token");
        }

        require(tokensToBuy <= tokensForSale, "Not enough tokens left for sale");

        tokensForSale -= tokensToBuy;
        tokensPurchased[msg.sender] += tokensToBuy;
        totalTokensSold += tokensToBuy;

        emit TokensPurchased(msg.sender, tokensToBuy);

        if (tokensForSale == 0) {
            endPresale();
        }
    }

    function getETHInUSDT(uint256 wethAmount) public view returns (uint256) {
        // Assume a price feed or oracle to get the conversion rate from ETH to USDT
        // For simplicity, you can use a fixed rate or integrate Chainlink for dynamic pricing
        return wethAmount * 3000; // Example: 1 WETH = 3000 USDT
    }

    function endPresale() public onlyOwner {
        require(block.timestamp > presaleEndTime || tokensForSale == 0, "Presale cannot be ended yet");
        require(!presaleEnded, "Presale has already ended");

        presaleEnded = true;
        emit PresaleEnded(totalTokensSold);
    }

    function withdrawFunds() external onlyOwner {
        require(presaleEnded, "Presale has not ended yet");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
        emit FundsWithdrawn(balance);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(presaleEnded, "Presale has not ended yet");
        uint256 unsoldTokens = tokensForSale;
        require(unsoldTokens > 0, "No unsold tokens left");

        tokensForSale = 0;
        require(aitToken.transfer(owner(), unsoldTokens), "Token transfer failed");
    }

    function setTokenPriceInUSDT(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Invalid token price");
        tokenPriceInUSDT = _newPrice;
    }
}
