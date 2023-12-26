// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StealthSale is Ownable {
    using SafeMath for uint256;

    address public token;
    address busdToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    address payable public liquidityReceiver =
        payable(0x4Acc87922b9768De2e6388E2D06697F1AE362971);
    address payable public treasury =
        payable(0x3C42D87cF99EDfBBE1738Cc3c6996BE66ae32aCF);

    uint256 public bnbRate;
    uint256 public busdRate = 8;
    uint256 public decimals = 10 ** 18;
    uint256 public minBuy = 10 * decimals;
    uint256 public maxBuy = 3000 * decimals;
    uint256 public goal = 300000 * decimals;
    uint256 public totalRaised;

    bool public hasEnded = false;

    mapping(address => bool) whitelist;
    mapping(address => uint256) public totalPurchased;

    event TokenPurchase(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );

    constructor(uint256 _rate, address _token) {
        require(_rate > 0);
        bnbRate = _rate;
        token = _token;
    }

    receive() external payable {
        buyTokens();
    }

    function buyTokens() public payable {
        uint256 weiAmountInBusd = (msg.value).mul(bnbRate);
        uint256 tokens = _getTokenAmount(weiAmountInBusd);

        _prevalidate(weiAmountInBusd);
        _deliverTokens(tokens);
        _updatePurchasingState(weiAmountInBusd);
        _forwardFunds();

        emit TokenPurchase(msg.sender, weiAmountInBusd, tokens);
    }

    function buyTokensWithBUSD(uint256 busdAmount) public payable {
        uint256 tokens = _getTokenAmount(busdAmount);

        _prevalidate(busdAmount);
        _deliverTokens(tokens);
        _updatePurchasingState(busdAmount);
        _forwardBusd(busdAmount);

        emit TokenPurchase(msg.sender, busdAmount, tokens);
    }

    function _prevalidate(uint256 _weiAmount) internal view {
        require(!hasEnded, "Presale ended");
        require(totalRaised <= goal, "Reached presale limit");
        require(_weiAmount >= minBuy, "Buy amount too low");
        require(
            totalPurchased[msg.sender].add(_weiAmount) < maxBuy,
            "Buy limit reached. Try a lower amount."
        );
    }

    function _deliverTokens(uint256 _tokenAmount) internal {
        IERC20(token).transfer(msg.sender, _tokenAmount);
    }

    function _updatePurchasingState(uint256 _weiAmount) internal {
        totalRaised = totalRaised.add(_weiAmount);
        totalPurchased[msg.sender] = totalPurchased[msg.sender].add(_weiAmount);
    }

    function _getTokenAmount(
        uint256 _weiAmount
    ) internal view returns (uint256) {
        uint256 baseAmount = _weiAmount.mul(100).div(busdRate);
        if (whitelist[msg.sender]) {
            return baseAmount.mul(2);
        } else {
            return baseAmount;
        }
    }

    function _forwardFunds() internal {
        (bool success, ) = liquidityReceiver.call{
            value: msg.value.mul(70).div(100),
            gas: 30000
        }("");
        (success, ) = treasury.call{
            value: msg.value.mul(30).div(100),
            gas: 30000
        }("");
    }

    function _forwardBusd(uint256 _busdAmount) internal {
        IERC20(busdToken).transferFrom(
            msg.sender,
            liquidityReceiver,
            _busdAmount.mul(70).div(100)
        );
        IERC20(busdToken).transferFrom(
            msg.sender,
            treasury,
            _busdAmount.mul(30).div(100)
        );
    }

    function sendTokens(
        uint256 _tokenAmount,
        address _token
    ) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _tokenAmount);
    }

    function updateBnbRate(uint256 _rate) external onlyOwner {
        bnbRate = _rate;
    }

    function updateWhitelist(address[] calldata recipients) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            whitelist[recipients[i]] = true;
        }
    }

    function checkWhitelist(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    function clearBalance() external onlyOwner {
        uint256 amount = address(this).balance;
        treasury.transfer(amount);
    }

    function endSale() external onlyOwner {
        hasEnded = true;
    }
}
