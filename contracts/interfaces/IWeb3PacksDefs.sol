// SPDX-License-Identifier: MIT

// IWeb3PacksDefs.sol
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

interface IWeb3PacksDefs {
  // Custom Errors
  error NotOwnerOrApproved();
  error FundingFailed();
  error NullReceiver();
  error ContractNotAllowed();
  error NativeAssetTransferFailed();
  error MismatchedTokens();
  error NoBundlesInPack();
  error BundlerNotRegistered(bytes32 bundlerId);
  error MissingLiquidityUUID(address tokenAddress);
  error UnsucessfulSwap(address tokenOut, uint256 amountIn, address router);
  error InsufficientForFee(uint256 value, uint256 ethPackPrice, uint256 protocolFee);

  struct RouterConfig {
    address weth;
    address primaryToken;
    address router;
    address manager;
    bytes32 bundlerId;
    int24 tickLower;
    int24 tickUpper;
  }

  struct BundleChunk {
    bytes32 bundlerId;
    uint256 percentBasisPoints;
  }

  struct Token {
    address tokenAddress;
    uint256 tokenDecimals;
    string tokenSymbol;
  }

  struct Route {
    address token0;
    address token1;
    bool stable;
  }

  struct LiquidityPosition {
    uint256 lpTokenId;
    uint256 liquidity;
    bool stable;
  }

  struct LockState {
    uint256 ERC20Timelock;
    uint256 ERC721Timelock;
  }
}
