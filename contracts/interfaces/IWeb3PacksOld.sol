// SPDX-License-Identifier: MIT

// IWeb3PacksOld.sol
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

interface IWeb3PacksOld {
  /***********************************|
  |    For Backwards Compatibility    |
  |__________________________________*/

  enum RouterType {
    UniswapV2,
    UniswapV3,
    Velodrome,
    Balancer,
    SwapMode
  }

  struct LiquidityPosition {
    uint256 lpTokenId;
    uint256 liquidity;
    bool stable;
    address token0;
    address token1;
    int24 tickLower;
    int24 tickUpper;
    bytes32 poolId;
    address router;
    RouterType routerType;
  }

  function getLiquidityPositions(uint256 tokenId) external returns (LiquidityPosition[] memory positions);
}
