// SPDX-License-Identifier: MIT

// Web3PacksState.sol
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
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./lib/BlackholePrevention.sol";
import "./interfaces/IWeb3Packs.sol";
import "./interfaces/IWeb3PacksState.sol";

contract Web3PacksState is
  IWeb3PacksState,
  Ownable,
  ReentrancyGuard,
  BlackholePrevention
{
  using Address for address payable;

  event Web3PacksSet(address indexed web3packs);
  event BundlerRegistered(address indexed bundlerAddress, bytes32 bundlerId);
  event BalanceClaimed(address indexed account, uint256 balance);
  event RewardsMigrated(address indexed newWeb3state, uint256 balance);

  address public _web3packs;

  mapping (bytes32 => address) internal _bundlersById;
  mapping (uint256 => uint256) internal _packPriceByPackId;
  mapping (uint256 => bytes32[]) internal _bundlesByPackId;
  mapping (address => uint256) internal _referrerBalance;

  constructor(address web3packs) {
    _web3packs = web3packs;
  }

  receive() external payable {}

  modifier onlyWeb3Packs() {
    require(msg.sender == _web3packs, "Web3PacksState - Only Web3Packs");
    _;
  }

  function getBundlerById(bytes32 bundlerId) external view returns (address bundler) {
    bundler = _bundlersById[bundlerId];
  }

  function getPackPriceByPackId(uint256 tokenId) external view returns (uint256 packPrice) {
    packPrice = _packPriceByPackId[tokenId];
  }

  function getBundlesByPackId(uint256 tokenId) external view returns (bytes32[] memory bundles) {
    bundles = _bundlesByPackId[tokenId];
  }

  function getReferrerBalance(address referrer) external view returns (uint256 balance) {
    balance = _referrerBalance[referrer];
  }

  function claimReferralRewards(address payable account) external nonReentrant {
    uint256 balance = _referrerBalance[account];
    if (address(this).balance >= balance) {
      account.sendValue(balance);
      delete _referrerBalance[account];
      emit BalanceClaimed(account, balance);
    }
  }


  /***********************************|
  |         Only Web3 Packs           |
  |__________________________________*/

  function setPackPriceByPackId(uint256 tokenId, uint256 packPrice) external onlyWeb3Packs {
    if (packPrice > 0) {
      _packPriceByPackId[tokenId] = packPrice;
    } else {
      delete _packPriceByPackId[tokenId];
    }
  }

  function setBundlesByPackId(uint256 tokenId, bytes32[] memory bundles) external onlyWeb3Packs {
    if (bundles.length > 0) {
      _bundlesByPackId[tokenId] = bundles;
    } else {
      delete _bundlesByPackId[tokenId];
    }
  }

  function addToReferrerBalance(address referrer, uint256 amount) external onlyWeb3Packs {
    _referrerBalance[referrer] += amount;
  }


  /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

  function setWeb3Packs(address web3packs) external onlyOwner {
    require(web3packs != address(0), "Invalid address for treasury");
    _web3packs = web3packs;
    emit Web3PacksSet(web3packs);
  }

  function registerBundlerId(bytes32 bundlerId, address bundlerAddress) external onlyOwner {
    _bundlersById[bundlerId] = bundlerAddress;
    emit BundlerRegistered(bundlerAddress, bundlerId);
  }

  function migratePackData(address oldWeb3Packs, uint256 tokenId, bytes32[] memory bundleIds) public onlyOwner {
    uint256 packPriceEth = IWeb3Packs(oldWeb3Packs).getPackPriceEth(tokenId);
    _packPriceByPackId[tokenId] = packPriceEth;
    _bundlesByPackId[tokenId] = bundleIds;
  }

  function migrateRewards(address payable newWeb3state) public onlyOwner {
    uint256 balance = address(this).balance;
    if (balance > 0) {
      newWeb3state.sendValue(balance);
      emit RewardsMigrated(newWeb3state, balance);
    }
  }

  /***********************************|
  |          Only Admin/DAO           |
  |      (blackhole prevention)       |
  |__________________________________*/

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
}
