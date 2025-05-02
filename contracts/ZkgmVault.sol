// SPDX-License-Identifier: MIT

// ZkgmVault.sol
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

pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "./lib/BlackholePrevention.sol";
import "./interfaces/IWeb3Packs.sol";
import "./interfaces/IWeb3PacksVault.sol";
import "./interfaces/union/IZkgmable.sol";

contract ZkgmVault is
  IWeb3PacksVault,
  IZkgmable,
  ERC165,
  Ownable,
  BlackholePrevention
{
  using Address for address payable;
  using ERC165Checker for address payable;
  using SafeERC20 for *;

  event Web3PacksSet(address indexed web3packs);
  event ZkgmSet(address indexed zkgm);
  event BalanceClaimed(address indexed account, uint256 balance);
  event RewardsMigrated(address indexed newWeb3state, uint256 balance);
  event MessageReceived(uint256 path, uint32 sourceChannelId, uint32 destinationChannelId, address sender, bytes message);

  address public _zkgm;
  address public _web3packs;
  mapping (address => uint256) internal _referrerBalance;

  constructor(address web3packs, address zkgm) Ownable() {
    _zkgm = zkgm;
    _web3packs = web3packs;
  }

  receive() external payable {}

  modifier onlyWeb3Packs() {
    require(msg.sender == _web3packs, "Web3PacksVault - Only Web3Packs");
    _;
  }

  modifier onlyWeb3PacksOrZkgm() {
    require(msg.sender == _zkgm || msg.sender == _web3packs, "Web3PacksVault - Only Web3Packs or ZKGM");
    _;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IWeb3PacksVault).interfaceId
      || interfaceId == type(IZkgmable).interfaceId
      || super.supportsInterface(interfaceId);
  }

  function getReferrerBalance(address account) external view returns (uint256 balance) {
    balance = _referrerBalance[account];
  }


  /***********************************|
  |         Only Web3 Packs           |
  |__________________________________*/

  function updateReferrerBalances(uint256, address[] memory referrers, uint256[] memory amounts) external onlyWeb3PacksOrZkgm {
    require(referrers.length == amounts.length, "Input length mismatch");
    for (uint256 i = 0; i < referrers.length; i++) {
      _referrerBalance[referrers[i]] += amounts[i];
    }
  }

  function claimReferralRewards(address payable account) external onlyWeb3Packs {
    uint256 balance = _referrerBalance[account];
    if (address(this).balance >= balance) {
      account.sendValue(balance);
      delete _referrerBalance[account];
      emit BalanceClaimed(account, balance);
    }
  }


  /***********************************|
  |         Only Union-ZKGM           |
  |__________________________________*/

  function onZkgm(
    address,
    uint256 path,
    uint32 sourceChannelId,
    uint32 destinationChannelId,
    bytes calldata sender,
    bytes calldata message,
    address,
    bytes calldata
  ) external onlyWeb3PacksOrZkgm {
    // Verify that the sourceChannelId and sender are authorized...
    // todo..

    // Process the cross-chain message
    emit MessageReceived(
      path,
      sourceChannelId,
      destinationChannelId,
      address(bytes20(sender)),
      message
    );
  }

  function onIntentZkgm(
    address,
    uint256,
    uint32,
    uint32,
    bytes calldata,
    bytes calldata,
    address,
    bytes calldata
  ) external onlyWeb3PacksOrZkgm {
    // no-op
  }

  /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

  function setWeb3Packs(address web3packs) external onlyOwner {
    require(web3packs != address(0), "Invalid address for web3packs");
    _web3packs = web3packs;
    emit Web3PacksSet(web3packs);
  }

  function setZkgm(address zkgm) external onlyOwner {
    _zkgm = zkgm;
    emit ZkgmSet(zkgm);
  }

  function migrateRewards(address payable newVault) public onlyOwner {
    require(newVault.supportsInterface(type(IWeb3PacksVault).interfaceId), "Invalid Vault");
    uint256 balance = address(this).balance;
    if (balance > 0) {
      newVault.sendValue(balance);
      emit RewardsMigrated(newVault, balance);
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
