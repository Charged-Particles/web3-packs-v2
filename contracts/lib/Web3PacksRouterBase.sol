// SPDX-License-Identifier: MIT

// Web3PacksRouterBase.sol
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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./BlackholePrevention.sol";
import "../interfaces/IWeb3PacksRouter.sol";
import "../interfaces/IWeb3PacksDefs.sol";

abstract contract Web3PacksRouterBase is
  IWeb3PacksRouter,
  Ownable,
  BlackholePrevention
{
  using Address for address payable;

  address public _weth;
  address public _manager;
  address public _token0;
  address public _token1;

  address public _swapRouter;
  address public _liquidityRouter;
  bytes32 public _poolId;

  // The ID Associated with this Bundler (must be Registered with Web3Packs)
  bytes32 public _bundlerId;

  uint256 public _slippage;
  int24 public _tickLower;
  int24 public _tickUpper;

  // Store Liquidity Positions by Pack Token ID
  mapping(uint256 => IWeb3PacksDefs.LiquidityPosition) public _liquidityPositionsByTokenId;

  constructor(IWeb3PacksDefs.RouterConfig memory config) {
    _weth = config.weth;
    _token0 = config.token0;
    _token1 = config.token1;
    _manager = config.manager;
    _swapRouter = config.swapRouter;
    _liquidityRouter = config.liquidityRouter;
    _poolId = config.poolId;
    _bundlerId = config.bundlerId;
    _slippage = config.slippage;
    _tickLower = config.tickLower;
    _tickUpper = config.tickUpper;
  }

  receive() external payable {}

  /***********************************|
  |          Configuration            |
  |__________________________________*/

  /// @dev This should be overridden if Token0 is not WETH
  function getToken0() public virtual view returns (IWeb3PacksDefs.Token memory token0) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _weth,
      tokenDecimals: 18,
      tokenSymbol: "WETH"
    });
    return token;
  }

  /// @dev This should be overridden if Token1 is not WETH
  function getToken1() public virtual view returns (IWeb3PacksDefs.Token memory token1) {
    IWeb3PacksDefs.Token memory token = IWeb3PacksDefs.Token({
      tokenAddress: _weth,
      tokenDecimals: 18,
      tokenSymbol: "WETH"
    });
    return token;
  }

  /// @dev This can be overridden to specify custom routes/paths for swapping
  function getTokenPath(bool reverse) public virtual view returns (IWeb3PacksDefs.Route[] memory tokenPath) {
    IWeb3PacksDefs.Route[] memory tokens = new IWeb3PacksDefs.Route[](1);
    tokens[0] = reverse
      ? IWeb3PacksDefs.Route({token0: getToken1().tokenAddress, token1: getToken0().tokenAddress, stable: false})
      : IWeb3PacksDefs.Route({token0: getToken0().tokenAddress, token1: getToken1().tokenAddress, stable: false});
    return tokens;
  }

  /// @dev This can be overridden to specify custom ordering for swapping
  function getOrderedAssets(bool reverse) public virtual view returns (address[] memory, uint256[] memory) {
    address[] memory assets = new address[](2);
    assets[0] = reverse ? getToken1().tokenAddress : getToken0().tokenAddress;
    assets[1] = reverse ? getToken0().tokenAddress : getToken1().tokenAddress;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = reverse ? getBalanceToken1() : getBalanceToken0();
    amounts[1] = reverse ? getBalanceToken0() : getBalanceToken1();

    return (assets, amounts);
  }

  /// @dev This can be overridden to specify custom amounts for swapping
  function getLiquidityAmounts() public virtual view returns (uint256 amount0, uint256 amount1, uint256 minAmount0, uint256 minAmount1) {
    amount0 = getBalanceToken0();
    amount1 = getBalanceToken1();
    minAmount0 = (amount0 * (10000 - _slippage)) / 10000;
    minAmount1 = (amount1 * (10000 - _slippage)) / 10000;
  }

  /***********************************|
  |          Standard Code            |
  |__________________________________*/

  function getBalanceWeth() public virtual view returns (uint256 balanceWeth) {
    return IERC20(_weth).balanceOf(address(this));
  }

  function getBalanceToken0() public virtual view returns (uint256 balanceToken0) {
    return IERC20(getToken0().tokenAddress).balanceOf(address(this));
  }

  function getBalanceToken1() public virtual view returns (uint256 balanceToken1) {
    return IERC20(getToken1().tokenAddress).balanceOf(address(this));
  }

  function enterWeth(uint256 amount) internal virtual {
    IWETH(_weth).deposit{value: amount}();
  }

  function exitWethAndTransfer(address payable receiver) internal virtual returns (uint256 ethAmount) {
    uint256 wethBalance = getBalanceWeth();
    if (wethBalance > 0) {
      IWETH(_weth).withdraw(wethBalance);
    }
    ethAmount = address(this).balance;
    if (ethAmount != wethBalance) {
      revert FailedToExitWeth();
    }
    if (ethAmount > 0) {
      receiver.sendValue(ethAmount);
      emit EthTransferred(receiver, ethAmount);
    }
  }

  function refundUnusedTokens(address sender) internal virtual returns (uint256 unusedAmount0, uint256 unusedAmount1) {
    // Refund Unused Amounts
    unusedAmount0 = getBalanceToken0();
    if (unusedAmount0 > 0) {
      TransferHelper.safeTransfer(getToken0().tokenAddress, sender, unusedAmount0);
    }
    unusedAmount1 = getBalanceToken1();
    if (unusedAmount1 > 0) {
      TransferHelper.safeTransfer(getToken1().tokenAddress, sender, unusedAmount1);
    }
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external virtual pure returns(bytes4) {
    return this.onERC721Received.selector;
  }

  /***********************************|
  |          Only Admin/DAO           |
  |      (blackhole prevention)       |
  |__________________________________*/

  function setWeth(address weth) external virtual onlyOwner {
    _weth = weth;
  }

  function setSwapRouter(address router) external virtual onlyOwner {
    _swapRouter = router;
  }

  function setLiquidityRouter(address router) external virtual onlyOwner {
    _liquidityRouter = router;
  }

  function setManager(address manager) external virtual onlyOwner {
    _manager = manager;
  }

  function setSlippage(uint256 slippage) external virtual onlyOwner {
    _slippage = slippage;
  }

  function setTickLower(int24 tickLower) external virtual onlyOwner {
    _tickLower = tickLower;
  }

  function setTickUpper(int24 tickUpper) external virtual onlyOwner {
    _tickUpper = tickUpper;
  }

  function withdrawEther(address payable receiver, uint256 amount) external virtual onlyOwner {
    _withdrawEther(receiver, amount);
  }

  function withdrawErc20(address payable receiver, address tokenAddress, uint256 amount) external virtual onlyOwner {
    _withdrawERC20(receiver, tokenAddress, amount);
  }

  function withdrawERC721(address payable receiver, address tokenAddress, uint256 tokenId) external virtual onlyOwner {
    _withdrawERC721(receiver, tokenAddress, tokenId);
  }

  function withdrawERC1155(address payable receiver, address tokenAddress, uint256 tokenId, uint256 amount) external virtual onlyOwner {
    _withdrawERC1155(receiver, tokenAddress, tokenId, amount);
  }


  modifier onlyManagerOrSelf() {
    require(msg.sender == _manager || msg.sender == address(this), "Web3PacksRouterBase - Invalid Web3Packs Manager");
    _;
  }
}
