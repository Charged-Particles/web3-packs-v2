// SPDX-License-Identifier: MIT

// BalancerRouter.sol
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
import {IAsset, IBalancerV2Vault} from "../../../interfaces/mode/IBalancerV2Vault.sol";

abstract contract BalancerRouter is Web3PacksRouterBase {
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
    (address poolAddress, ) = IBalancerV2Vault(_liquidityRouter).getPool(_poolId);
    (uint256 balanceAmount0, uint256 balanceAmount1, , ) = getLiquidityAmounts();

    (address[] memory addresses, uint256[] memory amounts) = getOrderedAssets(false);
    IAsset[] memory assets = new IAsset[](addresses.length);
    for (uint i; i < addresses.length; i++) {
      assets[i] = IAsset(addresses[i]);
      TransferHelper.safeApprove(addresses[i], _liquidityRouter, amounts[i]);
    }

    // Add Liquidity
    bytes memory userData = abi.encode(IBalancerV2Vault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, 0);
    IBalancerV2Vault.JoinPoolRequest memory joinData = IBalancerV2Vault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: amounts,
      userData: userData,
      fromInternalBalance: false
    });
    IBalancerV2Vault(_liquidityRouter).joinPool(_poolId, address(this), address(this), joinData);

    lpTokenId = uint256(uint160(poolAddress));
    liquidity = IERC20(poolAddress).balanceOf(address(this));
    (amount0, amount1) = _getRemainders(balanceAmount0, balanceAmount1);
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
    (address poolAddress, ) = IBalancerV2Vault(_liquidityRouter).getPool(_poolId);

    (address[] memory addresses, uint256[] memory amounts) = getOrderedAssets(false);
    IAsset[] memory assets = new IAsset[](addresses.length);
    for (uint i; i < addresses.length; i++) { assets[i] = IAsset(addresses[i]); }

    TransferHelper.safeApprove(
      poolAddress,
      _liquidityRouter,
      liquidityPosition.liquidity
    );

    // Remove Liquidity
    bytes memory userData = abi.encode(IBalancerV2Vault.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, liquidityPosition.liquidity);
    IBalancerV2Vault.ExitPoolRequest memory exitData = IBalancerV2Vault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: amounts,
      userData: userData,
      toInternalBalance: false
    });
    IBalancerV2Vault(_liquidityRouter).exitPool(_poolId, address(this), payable(address(this)), exitData);

    (amount0, amount1) = _getRemainders(0, 0);
  }


  function _performSwap(uint256 percentOfAmount, address token0, address token1)
    internal
    returns (uint256 amountOut)
  {
    uint256 balance = IERC20(token0).balanceOf(address(this));
    uint256 swapAmount = (balance * percentOfAmount) / 10000;

    TransferHelper.safeApprove(token0, _swapRouter, swapAmount);

    if (swapAmount > 0) {
      IBalancerV2Vault.SingleSwap memory swapData = IBalancerV2Vault.SingleSwap({
        poolId: _poolId,
        kind: IBalancerV2Vault.SwapKind.GIVEN_IN,
        assetIn: IAsset(token0),
        assetOut: IAsset(token1),
        amount: swapAmount,
        userData: bytes("")
      });

      IBalancerV2Vault.FundManagement memory fundData = IBalancerV2Vault.FundManagement({
        sender: address(this),
        fromInternalBalance: false,
        recipient: payable(address(this)),
        toInternalBalance: false
      });
      IBalancerV2Vault(_swapRouter).swap(swapData, fundData, 0, block.timestamp);

      amountOut = IERC20(token1).balanceOf(address(this));
    }
  }

  function _getRemainders(uint256 balanceAmount0, uint256 balanceAmount1) internal view returns (uint256 amount0, uint256 amount1) {
    amount0 = getBalanceToken0();
    amount1 = getBalanceToken1();
    if (balanceAmount0 > 0) { amount0 = balanceAmount0 - amount0; }
    if (balanceAmount1 > 0) { amount1 = balanceAmount1 - amount1; }
  }
}
