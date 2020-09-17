pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "@nomiclabs/buidler/console.sol";
import "./oracles/IOracle.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is ERC20 {
    using SafeMath for uint;
    using WadMath for uint;

    address public oracle;
    FUM public fum;
    uint public minFumBuyPrice;                               // in units of ETH. default 0

    uint public constant WAD = 10 ** 18;
    uint public constant MIN_ETH_AMOUNT = WAD / 1000;         // 0.001 ETH
    uint public constant MIN_BURN_AMOUNT = WAD;               // 1 USM
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;       // 80%

    enum Side {Buy, Sell}

    event MinFumBuyPriceChanged(uint previous, uint latest);

    /**
     * @param oracle_ Address of the oracle
     */
    constructor(address oracle_) public ERC20("Minimal USD", "USM") {
        fum = new FUM();
        oracle = oracle_;
    }

    /** EXTERNAL FUNCTIONS **/

    /**
     * @notice Mint ETH for USM with checks and asset transfers. Uses msg.value as the ETH deposit.
     * @return USM minted
     */
    function mint() external payable returns (uint) {
        require(msg.value > MIN_ETH_AMOUNT, "0.001 ETH minimum");
        require(fum.totalSupply() > 0, "Fund before minting");
        uint usmMinted = ethToUsm(msg.value);
        _mint(msg.sender, usmMinted);
        return usmMinted;
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     *
     * @param usmToBurn Amount of USM to burn.
     * @return ETH sent
     */
    function burn(uint usmToBurn) external returns (uint) {
        require(usmToBurn >= MIN_BURN_AMOUNT, "1 USM minimum"); // TODO: Needed?
        uint ethToSend = usmToEth(usmToBurn);
        _burn(msg.sender, usmToBurn);
        Address.sendValue(msg.sender, ethToSend); // TODO: We have a reentrancy risk here
        require(debtRatio() <= WAD, "Debt ratio too high");
        return (ethToSend);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     */
    function fund() external payable {
        require(msg.value > MIN_ETH_AMOUNT, "0.001 ETH minimum"); // TODO: Needed?
        if(debtRatio() > MAX_DEBT_RATIO){
            // calculate the ETH needed to bring debt ratio to suitable levels
            uint ethNeeded = usmToEth(totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(ethPool()).add(1); //+ 1 to tip it over the edge
            if (msg.value >= ethNeeded) { // Split into two fundings at different prices
                _fund(msg.sender, ethNeeded);
                _fund(msg.sender, msg.value.sub(ethNeeded));
                return;
            } // Otherwise continue for funding the total at a single price
        }
        _fund(msg.sender, msg.value);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH
     * from the pool
     */
    function defund(uint fumAmount) external {
        require(fumAmount >= MIN_BURN_AMOUNT, "1 FUM minimum"); // TODO: Needed?
        uint ethAmount = fumAmount.wadMul(fumPrice(Side.Sell));
        fum.burn(msg.sender, fumAmount);
        Address.sendValue(msg.sender, ethAmount);
        require(debtRatio() <= MAX_DEBT_RATIO, "Max debt ratio breach");
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract)
     *
     * @return ETH pool
     */
    function ethPool() public view returns (uint) {
        return address(this).balance;
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public view returns (int) {
        uint pool = ethPool();
        int buffer = int(pool) - int(usmToEth(totalSupply()));
        require(buffer <= int(pool), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        uint pool = ethPool();
        if (pool == 0) {
            return 0;
        }
        return totalSupply().wadDiv(ethToUsm(pool));
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and ETH buffer
     */
    function fumPrice(Side side) public view returns (uint) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToEth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        uint theoreticalFumPrice = uint(ethBuffer()).wadDiv(fumTotalSupply);
        // if side == buy, floor the price at minFumBuyPrice
        if ((side == Side.Buy) && (minFumBuyPrice > theoreticalFumPrice)) {
            return minFumBuyPrice;
        }
        return theoreticalFumPrice;
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function ethToUsm(uint ethAmount) public view returns (uint) {
        return _oraclePrice().wadMul(ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function usmToEth(uint usmAmount) public view returns (uint) {
        return usmAmount.wadDiv(_oraclePrice());
    }

    /** INTERNAL FUNCTIONS */

    /**
     * @notice Set the min fum price, based on the current oracle price and debt ratio. Emits a MinFumBuyPriceChanged event.
     * @dev The logic for calculating a new minFumBuyPrice is as follows.  We want to set it to the FUM price, in ETH terms, at
     * which debt ratio was exactly MAX_DEBT_RATIO.  So we can assume:
     *
     *     usmToEth(totalSupply()) / ethPool() = MAX_DEBT_RATIO, or in other words:
     *     usmToEth(totalSupply()) = MAX_DEBT_RATIO * ethPool()
     *
     * And with this assumption, we calculate the FUM price (buffer / FUM qty) like so:
     *
     *     minFumBuyPrice = ethBuffer() / fum.totalSupply()
     *                    = (ethPool() - usmToEth(totalSupply())) / fum.totalSupply()
     *                    = (ethPool() - (MAX_DEBT_RATIO * ethPool())) / fum.totalSupply()
     *                    = (1 - MAX_DEBT_RATIO) * ethPool() / fum.totalSupply()
     */
    function _updateMinFumBuyPrice() internal {
        uint previous = minFumBuyPrice;
        if (debtRatio() <= MAX_DEBT_RATIO) {                // We've dropped below (or were already below, whatev) max debt ratio
            minFumBuyPrice = 0;                             // Clear mfbp
        } else if (minFumBuyPrice == 0) {                   // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            minFumBuyPrice = (WAD - MAX_DEBT_RATIO).wadMul(ethPool()).wadDiv(fum.totalSupply());
        }

        emit MinFumBuyPriceChanged(previous, minFumBuyPrice);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function _fund(address to, uint ethIn) internal {
        _updateMinFumBuyPrice();
        uint fumOut = ethIn.wadDiv(fumPrice(Side.Buy));
        fum.mint(to, fumOut);
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(IOracle(oracle).decimalShift(), UNIT) function.
        return IOracle(oracle).latestPrice().mul(WAD).div(10 ** IOracle(oracle).decimalShift());
    }
}