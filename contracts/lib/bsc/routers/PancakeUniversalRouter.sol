// SPDX-License-Identifier: MIT

// PancakeUniversalRouter.sol
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
import {IUniversalRouter} from "../../../interfaces/bsc/IPancakeUniversalRouter.sol";
import {Commands} from "./lib/PancakeUniversalCommands.sol";
import {Constants} from "./lib/PancakeUniversalConstants.sol";

// REF: https://developer.pancakeswap.finance/contracts/universal-router/addresses

// Pancake Universal Router
abstract contract PancakeUniversalRouter is Web3PacksRouterBase {
  struct PRoute {
    address from;
    address to;
    bool stable;
  }

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
    IWeb3PacksDefs.Route[] memory tokens = getTokenPath(reverse);
    PRoute[] memory routes = new PRoute[](tokens.length);
    for (uint i; i < tokens.length; i++) {
      routes[i] = PRoute({from: tokens[i].token0, to: tokens[i].token1, stable: tokens[i].stable});
    }
    amountOut = _performSwapV2(percentOfAmount, token0.tokenAddress, token1.tokenAddress, routes);
  }

  function swapCustom(uint256 percentOfAmount, address token0, address token1)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint256 amountOut)
  {
    PRoute[] memory routes = new PRoute[](1);
    routes[0] = PRoute({from: token0, to: token1, stable: false});
    amountOut = _performSwapV2(percentOfAmount, token0, token1, routes);
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
    lpTokenId = 0;
    liquidity = 0;
    amount0 = 0;
    amount1 = 0;
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

  function removeLiquidityPosition(IWeb3PacksDefs.LiquidityPosition memory)
    public
    virtual
    override
    onlyManagerOrSelf
    returns (uint amount0, uint amount1)
  {
    amount0 = 0;
    amount1 = 0;
  }


  function _performSwapV2(uint256 percentOfAmount, address token0, address token1, PRoute[] memory routes)
    internal
    returns (uint256 amountOut)
  {
    uint256 balance = IERC20(token0).balanceOf(address(this));
    uint256 swapAmount = (balance * percentOfAmount) / 10000;

    if (swapAmount > 0) {
      TransferHelper.safeApprove(token0, _swapRouter, swapAmount);
      bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
      bytes[] memory inputs = new bytes[](1);
      inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, routes, true);
      IUniversalRouter(_swapRouter).execute(commands, inputs, block.timestamp);
      amountOut = IERC20(token1).balanceOf(address(this));
      if (amountOut == 0) { revert SwapFailed(); }
      emit SwappedTokens(token0, token1, swapAmount, amountOut);
    }
  }

  function _performSwapV3(uint256 percentOfAmount, address token0, address token1, bytes memory path)
    internal
    returns (uint256 amountOut)
  {
    uint256 balance = IERC20(token0).balanceOf(address(this));
    uint256 swapAmount = (balance * percentOfAmount) / 10000;

    if (swapAmount > 0) {
      TransferHelper.safeApprove(token0, _swapRouter, swapAmount);
      bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
      bytes[] memory inputs = new bytes[](1);
      inputs[0] = abi.encode(Constants.MSG_SENDER, swapAmount, 0, path, true);
      IUniversalRouter(_swapRouter).execute(commands, inputs, block.timestamp);
      amountOut = IERC20(token1).balanceOf(address(this));
      if (amountOut == 0) { revert SwapFailed(); }
      emit SwappedTokens(token0, token1, swapAmount, amountOut);
    }
  }
}
