// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaFire is ERC20, Ownable {
    using SafeMath for uint256;

    // Constants
    uint256 public constant MAXIMUM_FEE = 2;
    uint256 private constant TOTAL_SUPPLY = 10 ** 6;

    // Variables
    uint256 private _burnFee = 0;
    uint256 private _liquidityFee = 0;
    uint256 private _treasuryFee = 2;
    uint256 private totalFee = 2;

    mapping(address => bool) private _isFeeExempt;
    mapping(address => bool) private _isLiquidityPair;

    address public liquidityReceiver;
    address public treasuryReceiver;

    // Event Emitters
    event UpdateFees(uint256 fee);
    event SetFeeExempt(address indexed _address, bool status);
    event UpdatePair(address indexed _address, bool status);
    event UpdateFeeReceivers(
        address indexed liquidityReceiver,
        address indexed treasuryReceiver
    );

    constructor() ERC20("MetaFire", "MR") {
        _mint(_msgSender(), TOTAL_SUPPLY * 10 ** decimals());

        liquidityReceiver = 0xF5fF8A60a00b9Efe01830c0c792F3596aC2A2028;
        treasuryReceiver = 0xF5fF8A60a00b9Efe01830c0c792F3596aC2A2028;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[liquidityReceiver] = true;
        _isFeeExempt[_msgSender()] = true;
        _isFeeExempt[address(this)] = true;

        _transferOwnership(treasuryReceiver);
    }

    function _transferWithFees(
        address from,
        address to,
        uint256 amount
    ) private {
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

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
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
        require(totalFee <= MAXIMUM_FEE, "Total fees higher than 2%");
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

    // Add liquidity pair
    function addPair(address _address, bool status) external onlyOwner {
        _isLiquidityPair[_address] = status;
        emit UpdatePair(_address, status);
    }

    function checkFeeExempt(address _address) public view returns (bool) {
        return _isFeeExempt[_address];
    }

    function totalFees() public view returns (uint256) {
        return totalFee;
    }
}
