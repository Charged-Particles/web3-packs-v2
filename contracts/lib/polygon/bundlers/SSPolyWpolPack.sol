// SPDX-License-Identifier: MIT

// SSPolyWpolPack.sol
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


// LINK: new Token(
//   Number(polygon.id),
//   '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39',
//   18,
//   'LINK',
//   'ChainLink LINK',
// ),
// UNI: new Token(
//   Number(polygon.id),
//   '0xb33eaad8d922b1083446dc23f610c2567fb5180f',
//   18,
//   'UNI',
//   'Uniswap (PoS) UNI',
// ),
// AAVE: new Token(
//   Number(polygon.id),
//   '0xd6df932a45c0f255f85145f286ea0b292b21c90b',
//   18,
//   'AAVE',
//   'Aave (PoS) AAVE',
// ),
// POL: new Token(
//   Number(polygon.id),
//   '0x0000000000000000000000000000000000001010',
//   18,
//   'POL',
//   'Polygon POL',
// ),
// CRV: new Token(
//   Number(polygon.id),
//   '0x172370d5cd63279efa6d502dab29171933a610af',
//   18,
//   'CRV',
//   'CRV (PoS) CRV',
// ),
// GRT: new Token(
//   Number(polygon.id),
//   '0x5fe2b58c013d7601147dcdd68c143a77499f5531',
//   18,
//   'GRT',
//   'Graph Token GRT',
// ),
// AXL: new Token(
//   Number(polygon.id),
//   '0x6e4E624106Cb12E168E6533F8ec7c82263358940',
//   6,
//   'AXL',
//   'Axelar (PoS)  AXL',
// ),

pragma solidity 0.8.27;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../routers/AlgebraRouter.sol";
import "../../../interfaces/IWeb3PacksBundler.sol";

/*
  Performs a Single-Sided Swap on QuickSwap Exchange using the Algebra Universal Router
  Token 0 = WPOL
  Token 1 = PACK
 */
contract SSPolyWpolPack is IWeb3PacksBundler, AlgebraRouter {
  // Inherit from the Algebra Router
  constructor(IWeb3PacksDefs.RouterConfig memory config) AlgebraRouter(config) {}

  /***********************************|
  |          Configuration            |
  |__________________________________*/

  // Token 0 = WPOL on Polygon (QuickSwap Exchange)
  function getToken0() public view override returns (IWeb3PacksDefs.Token memory token0) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _token0,
      tokenDecimals: 18,
      tokenSymbol: "WPOL"
    });
    return token;
  }

  // Token 1 = PACK on Polygon (QuickSwap Exchange)
  function getToken1() public view override returns (IWeb3PacksDefs.Token memory token1) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _token1,
      tokenDecimals: 18,
      tokenSymbol: "PACK"
    });
    return token;
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
