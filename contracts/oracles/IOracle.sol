// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

interface IOracle {
    function latestPrice() external view returns (uint);
    function decimalShift() external view returns (uint);
}