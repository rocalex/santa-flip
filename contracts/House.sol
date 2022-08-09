// contracts/House.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFeeBeneficiary.sol";

contract House is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    bool public houseLive = true;
    uint public lockedInBets;
    uint public lockedInRewards;
    uint public nftHoldersRewardsToDistribute;
    uint public balanceMaxProfitRatio = 1;
    address public houseOwner;
    IFeeBeneficiary public FeeBeneficiary;

    mapping(address => bool) private addressAdmin;
    mapping(address => uint) public playerBalance;

    // Events
    event Donation(address indexed player, uint amount);
    event BalanceClaimed(address indexed player, uint amount);
    event RewardsDistributed(uint nPlayers, uint amount);

    fallback() external payable {
        emit Donation(msg.sender, msg.value);
    }

    receive() external payable {
        emit Donation(msg.sender, msg.value);
    }

    modifier admin() {
        require(addressAdmin[msg.sender] == true, "You are not an admin");
        _;
    }

    modifier isHouseLive() {
        require(houseLive == true, "House not live");
        _;
    }

    constructor() {
        addressAdmin[msg.sender] = true;
    }

    // Getter
    function balance() public view returns (uint) {
        return address(this).balance;
    }

    // Setter
    function toggleHouseLive() external onlyOwner {
        houseLive = !houseLive;
    }

    function setBalanceMaxProfitRatio(uint _balanceMaxProfitRatio)
        external
        onlyOwner
    {
        balanceMaxProfitRatio = _balanceMaxProfitRatio;
    }

    // Methods
    function addAdmin(address _address) external onlyOwner {
        addressAdmin[_address] = true;
    }

    function removeAdmin(address _address) external onlyOwner {
        addressAdmin[_address] = false;
    }

    // Game methods
    function balanceAvailableForBet() public view returns (uint) {
        return balance() - lockedInBets - lockedInRewards;
    }

    function maxProfit() public view returns (uint) {
        return balanceAvailableForBet() / balanceMaxProfitRatio;
    }

    function placeBet(
        uint amount,
        uint winnableAmount,
        uint fee,
        uint nftHolderRewardsAmount
    ) external payable isHouseLive admin nonReentrant {
        require(winnableAmount <= maxProfit(), "MaxProfit violation");
        require(amount == msg.value, "Not right amount sent");

        lockedInBets += winnableAmount;
        nftHoldersRewardsToDistribute += nftHolderRewardsAmount;
        lockedInRewards += fee;
        FeeBeneficiary.transferFee{value: fee}();
    }

    function settleBet(
        address player,
        uint winnableAmount,
        bool win
    ) external isHouseLive admin nonReentrant {
        lockedInBets -= winnableAmount;
        if (win == true) {
            payable(player).transfer(winnableAmount);
        }
    }

    function payPlayer(address player, uint amount)
        external
        isHouseLive
        admin
        nonReentrant
    {
        require(amount <= maxProfit(), "MaxProfit violation");
        payable(player).transfer(amount);
    }

    function refundBet(
        address player,
        uint amount,
        uint winnableAmount
    ) external isHouseLive admin nonReentrant {
        lockedInBets -= winnableAmount;
        payable(player).transfer(amount);
    }

    function claimBalance() external isHouseLive nonReentrant admin {
        uint gBalance = playerBalance[msg.sender];
        require(gBalance > 0, "No funds to claim");
        payable(msg.sender).transfer(gBalance);
        playerBalance[msg.sender] = 0;
        lockedInRewards -= gBalance;
        emit BalanceClaimed(msg.sender, gBalance);
    }

    function distributeNftHoldersRewards(address[] memory addresses)
        external
        onlyOwner
    {
        require(nftHoldersRewardsToDistribute > 0, "No rewards to distribute");
        uint nHolders = addresses.length;
        uint singleReward = nftHoldersRewardsToDistribute / nHolders;
        for (uint i = 0; i < nHolders; i++) {
            playerBalance[addresses[i]] += singleReward;
        }
        emit RewardsDistributed(nHolders, nftHoldersRewardsToDistribute);
        nftHoldersRewardsToDistribute = 0;
    }

    function withdrawFunds(address payable beneficiary, uint withdrawAmount)
        external
        onlyOwner
    {
        require(
            withdrawAmount <= balanceAvailableForBet(),
            "Withdrawal exceeds limit"
        );
        beneficiary.transfer(withdrawAmount);
    }

    function getPlayerBalance(address player) public view returns (uint) {
        return playerBalance[player];
    }

    function trasnferFoundsOUT(uint _amount, address _to)
        public
        payable
        onlyOwner
    {
        payable(_to).transfer(_amount);
    }

    function trasnferFoundsIN() public payable returns (bool) {
        require(msg.value > 10);
        return true;
    }

    function setFeeBeneficiary(address _feeBeneficiary) external onlyOwner {
        FeeBeneficiary = IFeeBeneficiary(_feeBeneficiary);
    }
}
