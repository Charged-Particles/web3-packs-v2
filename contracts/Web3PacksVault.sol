// SPDX-License-Identifier: MIT

// Web3PacksVault.sol
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

contract Web3PacksVault is
  IWeb3PacksVault,
  ERC165,
  Ownable,
  BlackholePrevention
{
  using Address for address payable;
  using ERC165Checker for address payable;
  using SafeERC20 for address;

  event Web3PacksSet(address indexed web3packs);
  event ProxySet(address indexed proxy);
  event UpgradedVaultSet(address indexed upgradedVault);
  event BalanceClaimed(address indexed account, uint256 balance);
  event MessageReceived(uint256 path, uint32 sourceChannelId, uint32 destinationChannelId, address sender, bytes message);

  address internal _proxy;
  address internal _web3packs;
  address internal _upgradedVault; // Only set when a newer Vault is deployed and reaches into this Vault to claim old balances
  mapping (address => uint256) internal _referrerBalance;

  constructor(address web3packs, address proxy) Ownable() {
    require(web3packs != address(0), "Invalid address for web3packs");
    _web3packs = web3packs;
    _proxy = proxy; // optional
  }

  receive() external payable {}

  modifier onlyWeb3Packs() {
    require(
      msg.sender == _web3packs ||
      (_upgradedVault != address(0) && msg.sender == _upgradedVault),
      "Web3PacksVault - Only Web3Packs or Vault"
    );
    _;
  }

  modifier onlyWeb3PacksOrProxy() {
    require(
      msg.sender == _proxy ||
      msg.sender == _web3packs ||
      (_upgradedVault != address(0) && msg.sender == _upgradedVault),
      "Web3PacksVault - Only Web3Packs or Proxy"
    );
    _;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IWeb3PacksVault).interfaceId || super.supportsInterface(interfaceId);
  }

  function getReferrerBalance(address account) external view returns (uint256 balance) {
    balance = _referrerBalance[account];
  }

  /***********************************|
  |         Only Web3 Packs           |
  |__________________________________*/

  function updateReferrerBalances(uint256, address[] calldata referrers, uint256[] calldata amounts) external onlyWeb3PacksOrProxy {
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
  |          Only Admin/DAO           |
  |__________________________________*/

  function setWeb3Packs(address web3packs) external onlyOwner {
    require(web3packs != address(0), "Invalid address for web3packs");
    _web3packs = web3packs;
    emit Web3PacksSet(web3packs);
  }

  function setProxy(address proxy) external onlyOwner {
    _proxy = proxy;
    emit ProxySet(proxy);
  }

  function setUpgradedVault(address upgradedVault) external onlyOwner {
    require(upgradedVault != address(0), "Invalid address for upgraded vault");
    _upgradedVault = upgradedVault;
    emit UpgradedVaultSet(upgradedVault);
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
