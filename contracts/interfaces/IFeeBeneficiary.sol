// contracts/interfaces/IFeeBeneficiary.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IFeeBeneficiary {
    function transferFee() external payable;
}
