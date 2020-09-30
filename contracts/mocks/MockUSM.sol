// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../USM.sol";
import "@nomiclabs/buidler/console.sol";


/**
 * @title Mock Buffered Token
 * @author Alberto Cuesta Cañada (@acuestacanada)
 * @notice This contract gives access to the internal functions of USM for testing
 */
contract MockUSM is USM {

    constructor(address oracle_, address eth_) public USM(oracle_, eth_) { }

    function updateMinFumBuyPrice() public {
        _updateMinFumBuyPrice();
    }

    function oraclePrice() public view returns (uint) {
        return _oraclePrice();
    }

}