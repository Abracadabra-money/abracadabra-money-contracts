# GM cauldron integration guide

## Collateral
vanilla gmETH, gmARB or gmBTC

## Swappers
TokenSwapper for Leverage and Deleverage. Using 0x swap data to swap USDC to MIM or MIM to USDC

## References
- Gmx FE: https://github.com/gmx-io/gmx-interface
- GmRouterOrderParams: https://github.com/Abracadabra-money/abracadabra-money-contracts/blob/f257c00412cb762a4de4c9ec195fe7241006d31d/src/periphery/GmxV2CauldronOrderAgent.sol#L15
- See Tests for usage examples: https://github.com/Abracadabra-money/abracadabra-money-contracts/blob/main/test/GmxV2.t.sol

## Unleveraged Borrow
- deposit gm token
- add collateral
- borrow MIM

## Leveraged Borrow
- deposit gm token
- add collateral
- borrow MIM
- using token swapper, swap MIM to USDC -> deposit to order agent contract
- create gm token order with USDC (action 101), encode GmRouterOrderParams as data.
  - inputToken: USDC
  - deposit: true
  - inputAmount: usdc out from token swapper, in amount, not share.
  - executionFee see Gmx FE to calculate execution fee correctly, the excess is refunded, similar to LayerZero
  - minOutput: see Gmx FE to caculate min output to mint GM from USDC
  - minOutLong: 0
- send cook transaction
- use cauldron.orders(address) with user address to get the current order.
- Monitor Order state
  - When `order.isActive()` returns false the order is completed or cancelled (fail).
  - A successful order will no longer be active and cauldron.orders(address) will return address(0)
  - A failed order will no longer be active but cauldron.orders(address) will still return the order address
  - When an order success it will automatically deposit the GM token collateral and close the order.
  - When an order fails it will have USDC in there ready for withdrawal.
- To recover from a failed:
  - call order `refundWETH` using call cook action.
  - call cook action 9 and withdraw the USDC to USDC -> MIM Token Swapper. call cook action 9 data is `(address token, address to, uint256 amount, bool close)`.
    example: USDC address, token swapper address, usdc balance inside the order.
  - Repay with the MIM received

## Deleverage
- Remove collateral to order agent
- Cook action 101, create a withdrawal order, encode GmRouterOrderParams as data.
  - inputToken: gm token
  - deposit: false
  - inputAmount: gm token amount from previous step (Remove collateral), in amount, not share.
  - executionFee same as deposit but for withdrawing
  - minOutput: see explanation below
  - minOutLong: see explanation below
- Monitor Order state
  - When `order.isActive()` returns false the order is completed or cancelled (fail).
  - A successful order will no longer be active and cauldron.orders(address) will return address(0)
  - A failed order will no longer be active but cauldron.orders(address) will still return the order address
  - When an order success it will contain the USDC tokens
  - When an order fails it will have GM in there ready for withdrawal.
- To recover from a failed / retry deleveraging again:
  - call order `refundWETH` using call cook action.
  - call cook action 9 and withdraw the GM tokens and create a withdrawal order again like initially
- When the order is successful, USDC will be in the order.
- Withdraw from the order using cook action 9 and withdraw to the USDC -> MIM deleverage token swapper
- Swap using 0x swap data as usual and deposit to the use degenbox balance
- Repay

## MinOutput & minOutLong
to get these parameters use this GMXReader
https://arbiscan.io/address/0xf60becbba223EEA9495Da3f606753867eC10d139#readContract

### function `getWithdrawalAmountOut`
- dataStore is 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8
- market tuple: use reader `getMarket` function to get this parameter. `getMarket(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8, <address of the gm token>)
- prices (see `gmx-interface\src\domain\synthetics\markets\utils.ts`) `getContractMarketPrices` function to get the index,short and long prices.
- gmarketTokenAmount: market token amount to withdraw
- uiFeeReceiver: use address(0)
