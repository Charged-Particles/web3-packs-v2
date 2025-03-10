// SPDX-License-Identifier: MIT

// UniswapV2Router.sol
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
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../../Web3PacksRouterBase.sol";
import "../../../interfaces/IWeb3PacksDefs.sol";


abstract contract UniswapV2Router is Web3PacksRouterBase {
  // Pass constructor data
  constructor(IWeb3PacksDefs.RouterConfig memory config) Web3PacksRouterBase(config) {}

  // NOTE: Call via "staticCall" for Quote
  function quoteSwap() public payable virtual returns (uint256 amountOut) {
    enterWeth(msg.value);
    amountOut = swapSingle(10000, false);
  }

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
    (amount0, amount1, liquidity) = IUniswapV2Router02(_liquidityRouter).addLiquidity(
      token0.tokenAddress,
      token1.tokenAddress,
      balanceAmount0,
      balanceAmount1,
      minAmount0,
      minAmount1,
      address(this),
      block.timestamp
    );

    // Deposit the LP tokens into the Web3Packs NFT
    address lpTokenAddress = _getUniswapV2PairAddress(token0.tokenAddress, token1.tokenAddress);
    lpTokenId = uint256(uint160(lpTokenAddress));
  }

  function collectLpFees(IWeb3PacksDefs.LiquidityPosition memory)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint256 amount0, uint256 amount1)
  {
    amount0 = 0;
    amount1 = 0;
  }

  function removeLiquidityPosition(IWeb3PacksDefs.LiquidityPosition memory liquidityPosition)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint amount0, uint amount1)
  {
    IWeb3PacksDefs.Token memory token0 = getToken0();
    IWeb3PacksDefs.Token memory token1 = getToken1();

    address lpTokenAddress = _getUniswapV2PairAddress(token0.tokenAddress, token1.tokenAddress);
    TransferHelper.safeApprove(
      lpTokenAddress,
      _liquidityRouter,
      liquidityPosition.liquidity
    );

    // Release Liquidity
    (amount0, amount1) = IUniswapV2Router02(_liquidityRouter).removeLiquidity(
      token0.tokenAddress,
      token1.tokenAddress,
      liquidityPosition.liquidity,
      0,
      0,
      address(this),
      block.timestamp
    );
  }


  function _performSwap(uint256 percentOfAmount, address token0, address token1)
    internal
    returns (uint256 amountOut)
  {
    uint256 balance = IERC20(token0).balanceOf(address(this));
    uint256 swapAmount = (balance * percentOfAmount) / 10000;
    address[] memory path;
    path[0] = token0;
    path[1] = token1;

    if (swapAmount > 0) {
      TransferHelper.safeApprove(token0, _swapRouter, swapAmount);
      IUniswapV2Router02(_swapRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        0,
        path,
        address(this),
        block.timestamp
      );
      amountOut = IERC20(token1).balanceOf(address(this));
    }
  }

  function _getUniswapV2Factory() internal view returns (address) {
    return IUniswapV2Router02(_liquidityRouter).factory();
  }

  function _getUniswapV2PairAddress(address token0, address token1) internal view returns (address) {
    IUniswapV2Factory _factory = IUniswapV2Factory(_getUniswapV2Factory());
    return _factory.getPair(token0, token1);
  }
}
