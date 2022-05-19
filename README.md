# UBM - Minimalist USD Stablecoin

Originally proposed by [@jacob-eliosoff](https://github.com/jacob-eliosoff) in [this Medium article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8), UBM is an attempt to answer the question "What is the simplest possible decentralised stablecoin?"

## Networks & Addresses

### Baby UBM - Mainnet

[Live Stats](https://usmfum.github.io/UBM-Stats/)

Baby UBM is a "beta" version of UBM. Baby UBM expires on the 15th of January 2021 when it becomes withdraw-and-read-only. At this point, FUM and UBM will be redeemable for ETH, but no more minting of either can occur.

Baby UBM and Baby FUM is not redeemable for UBM or FUM. It is for test and reserach purposes only.

UBM: [0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC](https://etherscan.io/address/0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC)

FUM: [0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394](https://etherscan.io/address/0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394)

### Kovan

UBM: [0x21453979384f21D09534f8801467BDd5d90eCD6C](https://kovan.etherscan.io/address/0x21453979384f21D09534f8801467BDd5d90eCD6C)

FUM: [0x96F8F5323Aa6CB0e6F311bdE6DEEFb1c81Cb1898](https://kovan.etherscan.io/address/0x96F8F5323Aa6CB0e6F311bdE6DEEFb1c81Cb1898)

## How It Works

UBM is pegged to United States dollar, and maintains its stable value by minting UBM in exchange for ETH, using the price of ETH at the time of minting.

If ETH is worth $200, I deposit 1 ETH, I get 200 UBM in return (minus a small minting fee). The same goes for burning, but in the opposite direction.

This is what's known as a **CDP: Collateralised Debt Position.**

The problem with CDPs is that if the asset used as collateral drops in value, which in our case is highly probable at any time due to the volatility of ETH, the contract could become undercollateralised. This is where the concept of Minimalist Funding Tokens, or FUM, come in.

For more information on how FUM de-risks UBM, read [Jacob's original article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8).

**UPDATE:** Read part two on [protecting against price exploits](https://medium.com/@jacob.eliosoff/ubm-minimalist-stablecoin-part-2-protecting-against-price-exploits-a16f55408216).
