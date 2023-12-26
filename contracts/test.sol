// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Arbitrum is ERC20, Ownable {
    using SafeMath for uint256;

    string public _Website;

    uint256 public constant MAXIMUM_FEE = 10;
    uint256 private constant TOTAL_SUPPLY = 10 ** 9;

    uint256 private fee = 0;

    mapping(address => bool) private _isFeeExempt;
    mapping(address => bool) private _isPairContract;
    mapping(address => bool) public bots;

    event UpdateFees(uint256 fee);
    event SetFeeExempt(address indexed _address, bool status);
    event UpdatePair(address indexed _address, bool status);
    event BotListed(address indexed receiver, bool status);

    constructor() ERC20("Arbitrum", "ARB") {
        _mint(_msgSender(), TOTAL_SUPPLY * 10 ** decimals());

        _isFeeExempt[_msgSender()] = true;
        _isFeeExempt[address(this)] = true;
    }

    function _transferWithFees(
        address from,
        address to,
        uint256 amount
    ) private {
        require(!bots[from], "You're in BotList");
        if (!_isFeeExempt[from] && fee > 0 && _isPairContract[to]) {
            if (fee > 0) {
                _transfer(from, owner(), amount.mul(fee).div(100));
            }
            _transfer(from, to, amount.sub(amount.mul(fee).div(100)));
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

    function setFees(uint256 newFee) external onlyOwner {
        fee = newFee;
        require(fee <= MAXIMUM_FEE, "Total fees higher than 20%");
        emit UpdateFees(fee);
    }

    function setFeeExempt(address _address, bool status) external onlyOwner {
        _isFeeExempt[_address] = status;
        emit SetFeeExempt(_address, status);
    }

    function addPairContract(address _address, bool status) external onlyOwner {
        _isPairContract[_address] = status;
        emit UpdatePair(_address, status);
    }

    function checkFeeExempt(address _address) public view returns (bool) {
        return _isFeeExempt[_address];
    }

    function fees() public view returns (uint256) {
        return fee;
    }

    function updateLinks(string memory Website_URL) external onlyOwner {
        _Website = Website_URL;
    }

    function blockBot(address bot, bool status) external onlyOwner {
        bots[bot] = status;
        emit BotListed(bot, status);
    }
}
