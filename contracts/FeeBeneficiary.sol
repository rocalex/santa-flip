// contracts/FeeBeneficiary.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeBeneficiary is Ownable {
    address public feeHouse;
    uint public feePercentage;

    address public nftAddress;
    uint public nftHoldersRewardsPercentage;

    function transferFee() external payable {}

    function setFeeHouse(address _feeHouse) external onlyOwner {
        feeHouse = _feeHouse;
    }

    function setNftHoldersRewards(address _nftAddress) external onlyOwner {
        nftAddress = _nftAddress;
    }

    function setFees(uint _feePercentage) public onlyOwner {
        feePercentage = _feePercentage;
        nftHoldersRewardsPercentage = 100 - feePercentage;
    }

    function payRewards() external onlyOwner {
        uint256 amount = address(this).balance;
        uint256 fee = (amount * feePercentage) / 100;
        uint256 nftHoldersRewards = (amount * nftHoldersRewardsPercentage) /
            100;
        payable(feeHouse).transfer(fee);
        payable(nftAddress).transfer(nftHoldersRewards);
    }
}
