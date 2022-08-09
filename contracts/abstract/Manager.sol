// contracts/abstract/Manager.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IHouse {
    function placeBet(
        uint amount,
        uint winnableAmount,
        uint fee,
        uint nftHolderRewardsAmount
    ) external payable;

    function settleBet(
        address player,
        uint winnableAmount,
        bool win
    ) external;

    function refundBet(
        address player,
        uint amount,
        uint winnableAmount
    ) external;
}

interface IVRFManager {
    function sendRequestRandomness() external returns (bytes32);
}

abstract contract Manager is Ownable {
    using SafeERC20 for IERC20;
    IHouse house;
    IVRFManager VRFManager;

    // Variables
    bool public gameIsLive;
    uint public minBetAmount = 1 ether;
    uint public maxBetAmount = 50 ether;
    uint public maxCoinsBettable = 1;
    uint public houseEdgeBP = 350;
    uint public nftHoldersRewardsBP = 7500;
    uint public totalWins;
    uint public totalLosses;
    uint public totalVolume;

    address public VRFManagerAddress;

    struct Bet {
        //ever one
        //uint40 choice;
        uint40 outcome;
        uint168 placeBlockNumber;
        uint128 amount;
        uint128 winAmount;
        address player;
        bool isSettled;
    }

    Bet[] public bets;
    mapping(bytes32 => uint[]) public betMap;

    modifier isVRFManager() {
        require(VRFManagerAddress == msg.sender, "You are not allowed");
        _;
    }

    function betsLength() external view returns (uint) {
        return bets.length;
    }

    // Events
    event BetPlaced(uint indexed betId, address indexed player, uint amount);
    event Play(
        uint indexed betId,
        address indexed player,
        uint amount,
        uint outcome,
        uint winAmount
    );
    event BetRefunded(uint indexed betId, address indexed player, uint amount);

    // Setter
    function setMaxCoinsBettable(uint _maxCoinsBettable) external onlyOwner {
        maxCoinsBettable = _maxCoinsBettable;
    }

    function setMinBetAmount(uint _minBetAmount) external onlyOwner {
        require(
            _minBetAmount < maxBetAmount,
            "Min amount must be less than max amount"
        );
        minBetAmount = _minBetAmount;
    }

    function setMaxBetAmount(uint _maxBetAmount) external onlyOwner {
        require(
            _maxBetAmount > minBetAmount,
            "Max amount must be greater than min amount"
        );
        maxBetAmount = _maxBetAmount;
    }

    function setHouseEdgeBP(uint _houseEdgeBP) external onlyOwner {
        require(gameIsLive == false, "Bets in pending");
        houseEdgeBP = _houseEdgeBP;
    }

    function setNftHoldersRewardsBP(uint _nftHoldersRewardsBP)
        external
        onlyOwner
    {
        nftHoldersRewardsBP = _nftHoldersRewardsBP;
    }

    function toggleGameIsLive() external onlyOwner {
        gameIsLive = !gameIsLive;
    }

    // Converters
    function amountToBettableAmountConverter(uint amount)
        internal
        view
        returns (uint)
    {
        return (amount * (10000 - houseEdgeBP)) / 10000;
    }

    function amountToNftHoldersRewardsConverter(uint _amount)
        internal
        view
        returns (uint)
    {
        return (_amount * nftHoldersRewardsBP) / 10000;
    }

    function amountToWinnableAmount(uint _amount) internal pure returns (uint) {
        return _amount * 2;
    }

    // Methods
    function initializeHouse(address _address) external onlyOwner {
        require(gameIsLive == false, "Bets in pending");
        house = IHouse(_address);
    }

    function initializeVRFManager(address _address) external onlyOwner {
        require(gameIsLive == false, "Bets in pending");
        VRFManager = IVRFManager(_address);
        VRFManagerAddress = _address;
    }

    function withdrawCustomTokenFunds(
        address beneficiary,
        uint withdrawAmount,
        address token
    ) external onlyOwner {
        require(
            withdrawAmount <= IERC20(token).balanceOf(address(this)),
            "Withdrawal exceeds limit"
        );
        IERC20(token).safeTransfer(beneficiary, withdrawAmount);
    }

    //MY integrations
    function calculateFee(uint _value) public view returns (uint) {
        uint txFee = (_value * houseEdgeBP) / 10000;
        return txFee;
    }

    function calculateValue(uint _value) public view returns (uint) {
        uint totalValue = calculateFee(_value) + _value;
        return totalValue;
    }
}
