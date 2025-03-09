// SPDX-License-Identifier: MIT

// SSWethSmd.sol
// Copyright (c) 2025 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity 0.8.17;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../routers/PancakeRouter.sol";
import "../../../interfaces/IWeb3PacksBundler.sol";

/*
  Performs a Single-Sided Swap on SwapMode Exchange using the Pancake Router
  Token 0 = WETH
  Token 1 = SMD
 */
contract SSWethSmd is IWeb3PacksBundler, PancakeRouter {
  // Inherit from the Pancake Router
  constructor(IWeb3PacksDefs.RouterConfig memory config) PancakeRouter(config) {}

  /***********************************|
  |          Configuration            |
  |__________________________________*/

  // Token 1 = SMD on Mode (SwapMode Exchange)
  function getToken1() public view override returns (IWeb3PacksDefs.Token memory token1) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _token1,
      tokenDecimals: 18,
      tokenSymbol: "SMD"
    });
    return token;
  }

  function getLiquidityToken(uint256) public override view returns (address tokenAddress, uint256 tokenId) {
    tokenAddress = getToken1().tokenAddress;
    tokenId = 0;
  }

  /***********************************|
  |          Standard Code            |
  |__________________________________*/

  // NOTE: Call via "staticCall" for Quote
  function quoteSwap() public payable virtual returns (uint256 amountOut) {
    enterWeth(msg.value);
    amountOut = swapSingle(10000, false);
  }

  function bundle(uint256, address sender)
    payable
    external
    override
    onlyManagerOrSelf
    returns(
      address tokenAddress,
      uint256 amountOut,
      uint256 nftTokenId
    )
  {
    // Perform Swap
    amountOut = swapSingle(10000, false); // 100% WETH -> SMD

    // Transfer back to Manager
    tokenAddress = getToken1().tokenAddress;
    nftTokenId = 0;
    TransferHelper.safeTransfer(tokenAddress, _manager, amountOut);

    // Refund Unused Amounts
    refundUnusedTokens(sender);
  }

  function unbundle(address payable receiver, uint256, bool sellAll)
    external
    override
    onlyManagerOrSelf
    returns(uint256 ethAmountOut)
  {
    if (sellAll) {
      // Perform Swap
      swapSingle(10000, true); // 100% SMD -> WETH

      // Send ETH to Receiver
      ethAmountOut = exitWethAndTransfer(receiver);
    } else {
      // Send Token to Receiver
      TransferHelper.safeTransfer(getToken1().tokenAddress, receiver, getBalanceToken1());
    }
  }
}
