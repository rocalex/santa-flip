// contracts/santaFlipers.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./abstract/Manager.sol";

contract Santaflip is ReentrancyGuard, Manager {
    function play(uint _value) external payable nonReentrant {
        require(gameIsLive, "Game is not live");
        uint fee = calculateFee(_value);
        uint amount = msg.value;
        //revisar este require
        require(
            amount >= minBetAmount && amount <= maxBetAmount,
            "Bet amount not within range"
        );
        require((_value + fee) == amount, "Error: amount != value + fee");
        //retorna (_value*2);
        uint winnableAmount = amountToWinnableAmount(_value);
        uint nftHolderRewardsAmount = amountToNftHoldersRewardsConverter(fee);

        house.placeBet{value: msg.value}(
            amount,
            winnableAmount,
            fee,
            nftHolderRewardsAmount
        );

        uint betId = bets.length;
        betMap[VRFManager.sendRequestRandomness()].push(betId);
        totalVolume += amount;

        emit BetPlaced(betId, msg.sender, _value);
        bets.push(
            Bet({
                outcome: 0,
                placeBlockNumber: uint168(block.number),
                amount: uint128(_value),
                winAmount: 0,
                player: msg.sender,
                isSettled: false
            })
        );
    }

    function settleBet(bytes32 requestId, uint256[] memory expandedValues)
        external
        isVRFManager
    {
        uint[] memory pendingBetIds = betMap[requestId];
        uint i;
        for (i = 0; i < pendingBetIds.length; i++) {
            // The VRFManager is optimized to prevent this from happening, this check is just to make sure that if it happens the tx will not be reverted, if this result is true the bet will be refunded manually later
            if (gasleft() <= 100000) {
                return;
            }
            // The pendingbets are always <= than the expandedValues
            _settleBet(pendingBetIds[i], expandedValues[i]);
        }
    }

    function _settleBet(uint betId, uint256 randomNumber) private nonReentrant {
        Bet storage bet = bets[betId];

        uint amount = bet.amount;
        if (amount == 0 || bet.isSettled == true) {
            return;
        }
        address player = bet.player;

        uint outcome = randomNumber % (100);
        uint winNum = 50;
        uint winnableAmount = amountToWinnableAmount(amount);
        uint winAmount = outcome > winNum ? winnableAmount : 0;

        bet.isSettled = true;
        bet.winAmount = uint128(winAmount);
        bet.outcome = uint40(outcome);

        house.settleBet(player, winnableAmount, winAmount > 0);

        if (winAmount > 0) {
            totalWins++;
        } else {
            totalLosses++;
        }

        emit Play(betId, player, amount, outcome, winAmount);
    }

    function refundBet(uint betId) external nonReentrant {
        require(gameIsLive, "Game is not live");
        Bet storage bet = bets[betId];
        uint amount = bet.amount;

        require(amount > 0, "Bet does not exist");
        require(bet.isSettled == false, "Bet is settled already");
        require(
            block.number > bet.placeBlockNumber + 21600,
            "Wait before requesting refund"
        );

        uint winnableAmount = amountToWinnableAmount(amount);
        uint bettedAmount = amount;

        bet.isSettled = true;
        bet.winAmount = uint128(bettedAmount);

        house.refundBet(bet.player, bettedAmount, winnableAmount);
        emit BetRefunded(betId, bet.player, bettedAmount);
    }
}
