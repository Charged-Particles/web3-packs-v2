// SPDX-License-Identifier: MIT

// IWeb3PacksState.sol
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

interface IWeb3PacksState {
  function getBundlerById(bytes32 bundlerId) external view returns (address bundler);
  function setPackPriceByPackId(uint256 tokenId, uint256 packPrice) external;
  function getPackPriceByPackId(uint256 tokenId) external view returns (uint256 packPrice);
  function setBundlesByPackId(uint256 tokenId, bytes32[] memory bundles) external;
  function getBundlesByPackId(uint256 tokenId) external view returns (bytes32[] memory bundles);
  function addToReferrerBalance(address referrer, uint256 amount) external;
  function getReferrerBalance(address referrer) external view returns (uint256 balance);
  function claimReferralRewards(address payable account) external;

  function setWeb3Packs(address web3packs) external;
  function registerBundlerId(bytes32 bundlerId, address bundlerAddress) external;
}
