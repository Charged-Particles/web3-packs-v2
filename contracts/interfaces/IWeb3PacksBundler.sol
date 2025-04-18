// SPDX-License-Identifier: MIT

// IWeb3PacksBundler.sol
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


interface IWeb3PacksBundler {
  event BundledTokenSS(address indexed token, uint256 amount);
  event BundledTokenLP(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidity);

  function getLiquidityToken(uint256 packTokenId) external returns (address tokenAddress, uint256 tokenId);

  function bundle(uint256 packTokenId, address sender)
    payable
    external
    returns(
      address tokenAddress,
      uint256 amountOut,
      uint256 nftTokenId
    );

  function unbundle(address payable receiver, uint256 packTokenId, bool sellAll)
    external
    returns(uint256 amountOut);
}
