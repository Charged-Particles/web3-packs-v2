// SPDX-License-Identifier: MIT

// SSBscWethBusd.sol
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
import "../routers/PancakeUniversalRouter.sol";
import "../../../interfaces/IWeb3PacksBundler.sol";

/*
  Performs a Single-Sided Swap using the Pancake Universal Router
  Token 0 = WETH (WBNB)
  Token 1 = BUSD
 */
contract SSBscWethBusd is IWeb3PacksBundler, PancakeUniversalRouter {
  address public _busd;

  // Inherit from the Algebra Router
  constructor(IWeb3PacksDefs.RouterConfig memory config, address busd) PancakeUniversalRouter(config) {
    _busd = busd;
  }

  /***********************************|
  |          Configuration            |
  |__________________________________*/

  // Token 1 = BUSD on BSC
  function getToken1() public view override returns (IWeb3PacksDefs.Token memory token1) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _token1,
      tokenDecimals: 18,
      tokenSymbol: "BUSD"
    });
    return token;
  }

  function getTokenPath(bool reverse) public override view returns (IWeb3PacksDefs.Route[] memory tokenPath) {
    IWeb3PacksDefs.Route[] memory tokens = new IWeb3PacksDefs.Route[](2);
    if (reverse) {
      tokens[0] = IWeb3PacksDefs.Route({token0: getToken1().tokenAddress, token1: _busd, stable: false});
      tokens[1] = IWeb3PacksDefs.Route({token0: _busd, token1: getToken0().tokenAddress, stable: false});
    } else {
      tokens[0] = IWeb3PacksDefs.Route({token0: getToken0().tokenAddress, token1: _busd, stable: false});
      tokens[1] = IWeb3PacksDefs.Route({token0: _busd, token1: getToken1().tokenAddress, stable: false});
    }
    return tokens;
  }

  /// @dev This can be overridden to specify custom liquidity tokens
  function getLiquidityToken(uint256) public virtual view returns (address tokenAddress, uint256 tokenId) {
    tokenAddress = getToken1().tokenAddress;
    tokenId = 0;
  }

  /***********************************|
  |          Standard Code            |
  |__________________________________*/

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
    amountOut = swapSingle(10000, false); // 100% token0 -> token1

    // Transfer back to Manager
    tokenAddress = getToken1().tokenAddress;
    nftTokenId = 0;
    TransferHelper.safeTransfer(tokenAddress, _manager, amountOut);

    // Refund Unused Amounts
    refundUnusedTokens(sender);
    emit BundledTokenSS(tokenAddress, amountOut);
  }

  function unbundle(address payable receiver, uint256, bool sellAll)
    external
    override
    onlyManagerOrSelf
    returns(uint256 ethAmountOut)
  {
    if (sellAll) {
      // Perform Swap
      swapSingle(10000, true); // 100% token1 -> token0

      // Send ETH to Receiver
      ethAmountOut = exitWethAndTransfer(receiver);
    } else {
      // Send Token to Receiver
      TransferHelper.safeTransfer(getToken1().tokenAddress, receiver, getBalanceToken1());
    }
  }
}
