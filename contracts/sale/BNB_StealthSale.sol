// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BNBStealthSale is Ownable {
    using SafeMath for uint256;

    address payable public treasury =
        payable(0x3C42D87cF99EDfBBE1738Cc3c6996BE66ae32aCF);
    address public distributor;

    uint256 public rate; // Tokens per 1 WETH
    uint256 public minBuy;
    uint256 public maxBuy;
    uint256 public goal;
    uint256 public totalRaised;

    bool public hasStarted = false;
    bool public hasEnded = false;

    mapping(address => uint256) public pendingRelease;
    mapping(address => uint256) public totalPurchased;

    event TokenPurchase(address indexed buyer, uint256 value, uint256 amount);
    event pendingReleased(address indexed receiver, uint256 amount);

    constructor() {}

    receive() external payable {
        buyTokens();
    }

    function buyTokens() public payable {
        uint256 tokenAmount = (msg.value).mul(rate); // Both WETH & token have 18 decimals

        _prevalidate(msg.value);
        _deliverTokens(tokenAmount);
        _updatePurchasingState(msg.value);
        _forwardFunds();

        emit TokenPurchase(msg.sender, msg.value, tokenAmount);
    }

    function _prevalidate(uint256 _weiAmount) internal view {
        require(hasStarted && !hasEnded, "Sale not available");
        require(
            _weiAmount >= minBuy ||
                (_weiAmount > 0 &&
                    maxBuy.sub(totalPurchased[msg.sender]) <= minBuy),
            "Buy amount too low"
        );
        require(
            totalPurchased[msg.sender].add(_weiAmount) <= maxBuy,
            "Buy limit reached. Try lower amount"
        );
    }

    function _deliverTokens(uint256 _tokenAmount) internal {
        uint256 currentAmount = pendingRelease[msg.sender];
        pendingRelease[msg.sender] = currentAmount.add(_tokenAmount);
    }

    function _updatePurchasingState(uint256 _weiAmount) internal {
        totalRaised = totalRaised.add(_weiAmount);
        totalPurchased[msg.sender] = totalPurchased[msg.sender].add(_weiAmount);
    }

    function _forwardFunds() internal {
        (bool success, ) = treasury.call{value: msg.value, gas: 30000}("");
    }

    function sendTokens(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        ); // Rescue stuck ERC20
    }

    function startSale(
        uint256 _goal,
        uint256 _rate,
        uint256 _maxBuy,
        uint256 _minBuy
    ) external onlyOwner {
        require(_goal > 0 && _rate > 0);
        goal = _goal;
        rate = _rate;
        minBuy = _minBuy;
        maxBuy = _maxBuy;
        hasStarted = true;
    }

    function endSale() external onlyOwner {
        hasEnded = true;
    }

    function updateRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    function clearBalance() external onlyOwner {
        uint256 amount = address(this).balance;
        treasury.transfer(amount);
    }

    function setMinMax(uint256 _maxBuy, uint256 _minBuy) external onlyOwner {
        minBuy = _minBuy;
        maxBuy = _maxBuy;
    }

    function getPendingRelease(
        address _address,
        bool clear
    ) external returns (uint256 _tokenAmount) {
        require(msg.sender == distributor, "No access");
        _tokenAmount = pendingRelease[_address];
        if (clear) {
            pendingRelease[_address] = 0;
            emit pendingReleased(msg.sender, _tokenAmount);
        }
        return _tokenAmount;
    }

    function setDistributor(address _address) external onlyOwner {
        distributor = _address;
    }

    function getDetails()
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        return (rate, totalRaised, goal, minBuy, maxBuy);
    }
}
