// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PinkLock {
    function vestingLock(
        address owner,
        address token,
        bool isLpToken,
        uint256 amount,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description
    ) external returns (uint256 id);
}

contract TokenRouter is Ownable {
    using SafeMath for uint256;

    address public token = 0x9c081Ec2C7A841A649Bd1B0ba68B4175F089eA0c;
    address public vestingContract = 0x6C9A0D8B1c7a95a323d744dE30cf027694710633;
    address public distributor;

    event TokenLocked(address indexed receiver, uint256 value, uint256 lockId);

    constructor() {
        IERC20(token).approve(vestingContract, IERC20(token).totalSupply());
    }

    function deliverTokens(
        uint256 _tokenAmount,
        address receiver
    ) external returns (uint256) {
        require(msg.sender == distributor, "No access");
        IERC20(token).transfer(receiver, _tokenAmount.div(100)); // 1% released for game
        uint256 lockAmount = _tokenAmount.mul(99).div(100);
        uint256 lockId = PinkLock(vestingContract).vestingLock(
            receiver,
            token,
            false,
            lockAmount, // 99% to Vesting Contract
            block.timestamp.add(7776000), // Wait 3 months
            500,
            2592000, // Monthly..
            500, // ..5% is released
            "Stealth Sale token vesting - 0 TGE, 5% per month"
        );
        emit TokenLocked(receiver, lockAmount, lockId);
        return lockId;
    }

    function sendTokens(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        ); // Rescue stuck ERC20
    }

    function setDistributor(address _address) external onlyOwner {
        distributor = _address;
    }
}
