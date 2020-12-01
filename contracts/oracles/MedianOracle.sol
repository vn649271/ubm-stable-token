// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./UniswapMedianSpotOracle.sol";
import "./Median.sol";

contract MedianOracle is ChainlinkOracle, CompoundOpenOracle, UniswapMedianSpotOracle {
    using SafeMath for uint;

    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair[NUM_UNISWAP_PAIRS] memory uniswapPairs,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens0Decimals,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens1Decimals,
        bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder
    ) public
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        UniswapMedianSpotOracle(uniswapPairs, uniswapTokens0Decimals, uniswapTokens1Decimals,
                                uniswapTokensInReverseOrder) {}

    function latestPrice() public override(ChainlinkOracle, CompoundOpenOracle, UniswapMedianSpotOracle)
        view returns (uint price)
    {
        price = Median.median(latestChainlinkPrice(),
                              latestCompoundPrice(),
                              latestUniswapMedianSpotPrice());
    }
}
