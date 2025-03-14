// SPDX-License-Identifier: MIT

// LPWethMode8020.sol
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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../routers/BalancerRouter.sol";
import "../../../interfaces/IWeb3PacksBundler.sol";

/*
  Creates a Liquidity Position on Balancer Exchange using the Balancer Router
  Token 0 = WETH 20%
  Token 1 = MODE 80%
 */
contract LPWethMode8020 is IWeb3PacksBundler, BalancerRouter {
  // Inherit from the Balancer Router
  constructor(IWeb3PacksDefs.RouterConfig memory config) BalancerRouter(config) {}

  /***********************************|
  |          Configuration            |
  |__________________________________*/

  // Token 0 = WETH
  // Token 1 = Mode on Mode (Kim Exchange)
  function getToken1() public view override returns (IWeb3PacksDefs.Token memory token1) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _token1,
      tokenDecimals: 18,
      tokenSymbol: "MODE"
    });
    return token;
  }

  function getLiquidityToken(uint256) public override view returns (address tokenAddress, uint256 tokenId) {
    (address poolAddress, ) = IBalancerV2Vault(_liquidityRouter).getPool(_poolId);
    tokenAddress = poolAddress;
    tokenId = 0;
  }

  /***********************************|
  |          Standard Code            |
  |__________________________________*/

  function bundle(uint256 packTokenId, address sender)
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
    swapSingle(8000, false); // 80% token0 -> token1

    // Deposit Liquidity
    (uint256 amount0, uint256 amount1, , ) = getLiquidityAmounts();
    (uint256 lpTokenId, uint256 liquidity, , ) = createLiquidityPosition(false);
    address poolAddress = address(uint160(lpTokenId));
    nftTokenId = 0;
    amountOut = liquidity;
    tokenAddress = poolAddress;

    // Transfer back to Manager
    TransferHelper.safeTransfer(poolAddress, _manager, amountOut);

    // Track Liquidity Position by Pack Token ID
    _liquidityPositionsByTokenId[packTokenId] = IWeb3PacksDefs.LiquidityPosition({
      lpTokenId: lpTokenId,
      liquidity: liquidity,
      stable: false
    });

    // Refund Unused Amounts
    (uint256 unusedAmount0, uint256 unusedAmount1) = refundUnusedTokens(sender);
    emit BundledTokenLP(
      getToken0().tokenAddress,
      getToken1().tokenAddress,
      amount0 - unusedAmount0,
      amount1 - unusedAmount1,
      liquidity
    );
  }

  function unbundle(address payable receiver, uint256 packTokenId, bool sellAll)
    external
    override
    onlyManagerOrSelf
    returns(uint256 ethAmountOut)
  {
    IWeb3PacksDefs.LiquidityPosition memory liquidityPosition = _liquidityPositionsByTokenId[packTokenId];

    // Perform Swap
    if (sellAll) {
      // Remove Liquidity
      removeLiquidityPosition(liquidityPosition);
      collectLpFees(liquidityPosition);

      // Swap Assets back to WETH
      swapSingle(10000, true); // 100% token1 -> token0
      ethAmountOut = exitWethAndTransfer(receiver);
    } else {
      // NOTE: For this Bundle, we want users to be able to Unbundle and receive the actual Liquidity for Voting Purposes
      (address lpTokenAddress, ) = getLiquidityToken(packTokenId);

      // Transfer Assets to Receiver
      TransferHelper.safeTransfer(lpTokenAddress, receiver, liquidityPosition.liquidity);
    }

    // Clear Liquidity Position
    delete _liquidityPositionsByTokenId[packTokenId];
  }
}
