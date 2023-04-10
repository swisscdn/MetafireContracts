// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaFire is ERC20, Ownable {
    using SafeMath for uint256;

    // Token social links will appear on Block Explorer
    string public Website;
    string public Telegram;
    string public LP_Locker_URL;

    // Constants
    uint256 public constant MAXIMUM_FEE = 2;
    uint256 private constant TOTAL_SUPPLY = 10**6;

    // Variables
    uint256 private _burnFee = 0;
    uint256 private _liquidityFee = 0;
    uint256 private _treasuryFee = 2;
    uint256 private totalFee = 2;
    bool public isLaunched = false;

    mapping(address => bool) private _isFeeExempt;
    mapping(address => bool) private _isLiquidityPair;
    mapping(address => bool) private knownBots;

    address public liquidityReceiver;
    address public treasuryReceiver;

    // Event Emitters
    event UpdateFees(uint256 fee);
    event SetFeeExempt(address indexed _address, bool status);
    event UpdatePair(address indexed _address, bool status);
    event BotListed(address indexed receiver, bool status);
    event UpdateFeeReceivers(
        address indexed liquidityReceiver,
        address indexed treasuryReceiver
    );

    constructor() ERC20("Metafire Gaming", "MR") {
        _mint(_msgSender(), TOTAL_SUPPLY * 10**decimals());

        liquidityReceiver = 0xb17ADDE1E7E9E2006Ec10BBb7625BA0238CA3FdE;
        treasuryReceiver = 0x6aAF9b7E170b7bAA6a75EB2C3D63d1cc397690e0;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[liquidityReceiver] = true;
        _isFeeExempt[_msgSender()] = true;
        _isFeeExempt[address(this)] = true;

        _transferOwnership(treasuryReceiver);
    }

    // Functions

    function _transferWithFees(
        address from,
        address to,
        uint256 amount
    ) private {
        require(!knownBots[from], "You're in BotList");
        if (!_isFeeExempt[from] && totalFee > 0 && _isLiquidityPair[to]) {
            if (_burnFee > 0) {
                _burn(from, amount.mul(_burnFee).div(100));
            }
            if (_treasuryFee > 0) {
                _transfer(
                    from,
                    treasuryReceiver,
                    amount.mul(_treasuryFee).div(100)
                );
            }
            if (_liquidityFee > 0) {
                _transfer(
                    from,
                    liquidityReceiver,
                    amount.mul(_liquidityFee).div(100)
                );
            }
            _transfer(from, to, amount.sub(amount.mul(totalFee).div(100)));
        } else {
            _transfer(from, to, amount);
        }
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transferWithFees(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithFees(from, to, amount);
        return true;
    }

    function setFees(
        uint256 liquidityFee,
        uint256 treasuryFee,
        uint256 burnFee
    ) external onlyOwner {
        _burnFee = burnFee;
        _liquidityFee = liquidityFee;
        _treasuryFee = treasuryFee;
        totalFee = _burnFee.add(_liquidityFee).add(_treasuryFee);
        require(totalFee <= MAXIMUM_FEE, "Total fees higher than 2%"); // Maximum fee is 2%
        emit UpdateFees(totalFee);
    }

    function setFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver
    ) external onlyOwner {
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        emit UpdateFeeReceivers(liquidityReceiver, treasuryReceiver);
    }

    function setFeeExempt(address _address, bool status) external onlyOwner {
        _isFeeExempt[_address] = status;
        emit SetFeeExempt(_address, status);
    }

    // Add/remove liquidity pair
    function addPair(address _address, bool status) external onlyOwner {
        _isLiquidityPair[_address] = status;
        emit UpdatePair(_address, status);
    }

    function preventBots(address bot, bool status) external onlyOwner {
        require(!isLaunched, "Launch phase is over");
        knownBots[bot] = status;
        emit BotListed(bot, status);
    }

    function setLaunched() external onlyOwner {
        isLaunched = true;
    }

    function updateLinks(
        string memory Website_URL,
        string memory Telegram_URL,
        string memory Liquidity_Locker_URL
    ) external onlyOwner {
        Website = Website_URL;
        Telegram = Telegram_URL;
        LP_Locker_URL = Liquidity_Locker_URL;
    }

    // Read only functions

    function totalFees() public view returns (uint256) {
        return totalFee;
    }

    function treasuryFees() public view returns (uint256) {
        return _treasuryFee;
    }

    function liquidityFees() public view returns (uint256) {
        return _liquidityFee;
    }

    function checkFeeExempt(address _address) public view returns (bool) {
        return _isFeeExempt[_address];
    }

    function isBotListed(address _address) public view returns (bool) {
        return knownBots[_address];
    }

    function isLiquidityPair(address _address) public view returns (bool) {
        return _isLiquidityPair[_address];
    }
}
