# LiquidationHelper Contract

A LiquidationHelper contract is deployed on all major chains at the following address:

```
0x82e07721837a740985186663b66423b0741960b6
```

This contract can be used to liquidate a position by providing the necessary MIM amount in exchange for the collateral plus the liquidation fee as an incentive.

## Liquidation Methods

A position can be liquidated using two methods:

1. **Max Liquidation**: The easiest method is to liquidate the entire position.
2. **Arbitrary Borrow Part Liquidation**: The other method requires providing a borrow part, which can be obtained by calling the `userBorrowPart` function on the specific cauldron to liquidate.

In both methods, MIM must be approved to be spent on `0x82e07721837a740985186663b66423b0741960b6`.

## Approving MIM

To approve MIM on `0x82e07721837a740985186663b66423b0741960b6`, go to Etherscan or the equivalent for other chains and go to the MIM contract address.

MIM addresses are the following:

- Mainnet: `0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3`
- Optimism: `0xB153FB3d196A8eB25522705560ac152eeEc57901`
- Avalanche: `0x130966628846BFd36ff31a822705796e8cb8C18D`
- Arbitrum: `0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A`
- BSC: `0xfE19F0B51438fd612f6FD59C1dbB3eA319f433Ba`

In the `Contract > Write Contract` tab, locate the `approve` function and enter the following:

- Spender: `0x82e07721837a740985186663b66423b0741960b6`
- Value: `115792089237316195423570985008687907853269984665640564039457584007913129639935`

Note that the `115792089237316195423570985008687907853269984665640564039457584007913129639935` is the maximum value, so there's no limit. Any reasonable amount can be used there. For example, `1000000000000000000000` would allow you to liquidate with a maximum of `1000 MIM`. The important thing is that the number must be 18 decimals.

Then click the `Write` button to send the transaction. After the transaction is completed, MIM is approved to be used to liquidate Abracadabra positions.

## Previewing Liquidations

On `0x82e07721837a740985186663b66423b0741960b6` on `Contract > Read Contract`, there are `preview` functions that indicate if a position is liquidatable for a given cauldron address, account, and, in the case of a partial liquidation, an optional borrow part. These functions also show the expected MIM that is required to liquidate and the expected collateral amount that will be returned if the liquidation succeeds. They can be used to validate and approximate the outcome of a liquidation.

> Note that Tenderly can also be used to simulate transactions and get more details about the liquidation and its results.

## Liquidation Functions

Once a liquidable position has been located, the following functions can be used to liquidate the position:

- `liquidate`: liquidate an account position on the given cauldron for the given borrow part. The cauldron version can be found by going to the cauldron etherscan (or equivalent) and looking at the contract name. For example, if the name is `CauldronV2Flat` the cauldron version is 2, `CauldronV4`, 4 and so on. As of now, most cauldrons use versions 2, 3, or 4.

- `liquidateMax`: same as `liquidate` function except the borrow part is not required as it will attempt to liquidate the full loan amount.

- `liquidateMaxTo` and `liquidateTo`: identical to `liquidateMax` and `liquidate`, except the collateral can be sent to another wallet instead of the caller's wallet.

To use these functions, go to the `Contract > Write Contract` tab and locate the appropriate function. Enter the required parameters, such as the cauldron address, the borrow part (if using the `liquidate` function), and the destination wallet (if using `liquidateMaxTo` or `liquidateTo`). Once all parameters are entered, click the `Write` button to send the transaction.