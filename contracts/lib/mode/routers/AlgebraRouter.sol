// SPDX-License-Identifier: MIT

// AlgebraRouter.sol
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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../../Web3PacksRouterBase.sol";
import "../../../interfaces/IWeb3PacksDefs.sol";
import "../../../interfaces/mode/IAlgebraRouter.sol";
import "../../../interfaces/mode/INonfungiblePositionManager.sol";


// UniswapV3-like Router
abstract contract AlgebraRouter is Web3PacksRouterBase {
  // Pass constructor data
  constructor(IWeb3PacksDefs.RouterConfig memory config) Web3PacksRouterBase(config) {}

  function swapSingle(uint256 percentOfAmount, bool reverse)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint256 amountOut)
  {
    IWeb3PacksDefs.Token memory token0 = reverse ? getToken1() : getToken0();
    IWeb3PacksDefs.Token memory token1 = reverse ? getToken0() : getToken1();
    amountOut = _performSwap(percentOfAmount, token0.tokenAddress, token1.tokenAddress);
  }

  function swapCustom(uint256 percentOfAmount, address token0, address token1)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint256 amountOut)
  {
    amountOut = _performSwap(percentOfAmount, token0, token1);
  }

  function createLiquidityPosition(bool)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (
      uint256 lpTokenId,
      uint256 liquidity,
      uint256 amount0,
      uint256 amount1
    )
  {
    IWeb3PacksDefs.Token memory token0 = getToken0();
    IWeb3PacksDefs.Token memory token1 = getToken1();
    (
      uint256 balanceAmount0,
      uint256 balanceAmount1,
      uint256 minAmount0,
      uint256 minAmount1
    ) = getLiquidityAmounts();

    TransferHelper.safeApprove(token0.tokenAddress, _liquidityRouter, balanceAmount0);
    TransferHelper.safeApprove(token1.tokenAddress, _liquidityRouter, balanceAmount1);

    // Add Liquidity
    INonfungiblePositionManager.MintParams memory params =
      INonfungiblePositionManager.MintParams({
        token0: token0.tokenAddress,
        token1: token1.tokenAddress,
        tickLower: _tickLower,
        tickUpper: _tickUpper,
        amount0Desired: balanceAmount0,
        amount1Desired: balanceAmount1,
        amount0Min: minAmount0,
        amount1Min: minAmount1,
        recipient: address(this),
        deadline: block.timestamp
      });
    (lpTokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(_liquidityRouter).mint(params);
  }

  function collectLpFees(IWeb3PacksDefs.LiquidityPosition memory liquidityPosition)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint256 amount0, uint256 amount1)
  {
    INonfungiblePositionManager.CollectParams memory params =
      INonfungiblePositionManager.CollectParams({
        tokenId: liquidityPosition.lpTokenId,
        recipient: address(this),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      });

    (amount0, amount1) = INonfungiblePositionManager(_liquidityRouter).collect(params);
  }

  function removeLiquidityPosition(IWeb3PacksDefs.LiquidityPosition memory liquidityPosition)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint amount0, uint amount1)
  {
    // Release Liquidity
    INonfungiblePositionManager.DecreaseLiquidityParams memory params =
      INonfungiblePositionManager.DecreaseLiquidityParams({
        tokenId: liquidityPosition.lpTokenId,
        liquidity: uint128(liquidityPosition.liquidity),
        amount0Min: 0, // liquidityPairs.token0.amount,
        amount1Min: 0, // liquidityPairs.token1.amount,
        deadline: block.timestamp
      });
    (amount0, amount1) = INonfungiblePositionManager(_liquidityRouter).decreaseLiquidity(params);
  }


  function _performSwap(uint256 percentOfAmount, address token0, address token1)
    internal
    returns (uint256 amountOut)
  {
    IAlgebraRouter.ExactInputSingleParams memory params;
    uint256 balance = IERC20(token0).balanceOf(address(this));
    uint256 swapAmount = (balance * percentOfAmount) / 10000;

    if (swapAmount > 0) {
      TransferHelper.safeApprove(token0, _swapRouter, swapAmount);
      params = IAlgebraRouter.ExactInputSingleParams(token0, token1, address(this), block.timestamp, swapAmount, 0, 0);
      IAlgebraRouter(_swapRouter).exactInputSingle(params);
      amountOut = IERC20(token1).balanceOf(address(this));
    }
  }
}
