// SPDX-License-Identifier: MIT

// ZkgmVaultProxy.sol
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
import "./interfaces/IWeb3PacksVaultBase.sol";
import "./interfaces/union/IZkgm.sol";
import "./interfaces/union/Lib.sol";

contract ZkgmVaultProxy is
  IWeb3PacksVaultBase,
  ERC165,
  Ownable,
  BlackholePrevention
{
  using Address for address payable;
  using ERC165Checker for address payable;
  using SafeERC20 for address;
  using ZkgmLib for IZkgm;

  event Web3PacksSet(address indexed web3packs);
  event Web3PacksVaultSet(address indexed web3packsVault);
  event ZkgmSet(address indexed zkgm);
  event RewardsTokenSet(address indexed rewardsToken);
  event RewardsQuoteTokenSet(address indexed rewardsToken);
  event ChannelIdSet(uint32 channelId);
  event DestinationPathSet(uint32 destinationPath);

  IZkgm internal _zkgm;
  address internal _web3packs;
  address internal _rewardsToken;
  uint32 internal _destinationPath;
  uint32 internal _destinationChannelId;
  bytes internal _web3packsVault;
  bytes internal _rewardsQuoteToken;


  constructor(address web3packs, address zkgm) Ownable() {
    require(web3packs != address(0), "Invalid address for web3packs");
    require(zkgm != address(0), "Invalid address for zkgm");
    _web3packs = web3packs;
    _zkgm = IZkgm(zkgm);
  }

  receive() external payable {}

  modifier onlyWeb3Packs() {
    require(msg.sender == _web3packs, "Web3PacksVault - Only Web3Packs");
    _;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IWeb3PacksVaultBase).interfaceId || super.supportsInterface(interfaceId);
  }


  /***********************************|
  |         Only Web3 Packs           |
  |__________________________________*/

  function updateReferrerBalances(uint256 referralAmountTotal, address[] calldata referrers, uint256[] calldata amounts) external onlyWeb3Packs {
    require(referrers.length == amounts.length, "Input length mismatch");

    // Approve Token Transfer to Zkgm
    IERC20(_rewardsToken).approve(address(_zkgm), referralAmountTotal);

    // Create Cross-chain Instructions
    Instruction memory instructions = _serializeInstructions(
      referralAmountTotal,
      referrers,
      amounts
    );

    // Send Cross-chain Transaction
    _zkgm.send(
      _destinationChannelId,
      uint64(block.timestamp + 60),
      0,          // block timeout [Optional]
      bytes32(0), // salt,
      instructions
    );
  }

  function _serializeInstructions(
    uint256 referralAmountTotal,
    address[] calldata referrers,
    uint256[] calldata amounts
  ) internal view returns (Instruction memory batchInstrunction) {
    Instruction[] memory instructions = new Instruction[](2);

    // Create fungible asset order instruction
    instructions[0] = _getTransferInstruction(referralAmountTotal);

    // Create Contract Call Instruction
    instructions[1] = _getUpdateInstruction(referralAmountTotal, referrers, amounts);

    // Create Batch Instruction
    batchInstrunction = ZkgmLib.makeBatch(instructions);
  }

  function _getTransferInstruction(uint256 referralAmountTotal) internal view returns (Instruction memory orderInstrunction) {
    // Create fungible asset order instruction
    orderInstrunction = IZkgm(_zkgm).makeFungibleAssetOrder(
      _destinationPath,
      _destinationChannelId,
      msg.sender,
      _web3packsVault,      // receiver,
      _rewardsToken,        // baseToken,
      referralAmountTotal,  // baseAmount,
      _rewardsQuoteToken,   // quoteToken,
      referralAmountTotal   // quoteAmount
    );
  }

  function _getUpdateInstruction(
    uint256 referralAmountTotal,
    address[] calldata referrers,
    uint256[] calldata amounts
  ) internal view returns (Instruction memory updateInstrunction) {
    // Create Contract Call Instruction
    updateInstrunction = ZkgmLib.makeMultiplexCall(
      msg.sender,
      false, // isEureka (IBC-style callbacks)
      _web3packsVault,
      abi.encodeCall(
        IWeb3PacksVaultBase.updateReferrerBalances,
        (referralAmountTotal, referrers, amounts)
      )
    );
  }


  /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

  function setWeb3Packs(address web3packs) external onlyOwner {
    require(web3packs != address(0), "Invalid address for web3packs");
    _web3packs = web3packs;
    emit Web3PacksSet(web3packs);
  }

  function setWeb3PacksVault(address web3packsVault) external onlyOwner {
    require(web3packsVault != address(0), "Invalid address for web3packsVault");
    _web3packsVault = abi.encodePacked(web3packsVault);
    emit Web3PacksVaultSet(web3packsVault);
  }

  function setZkgm(address zkgm) external onlyOwner {
    require(zkgm != address(0), "Invalid address for zkgm");
    _zkgm = IZkgm(zkgm);
    emit ZkgmSet(zkgm);
  }

  function setRewardsToken(address rewardsToken) external onlyOwner {
    require(rewardsToken != address(0), "Invalid address for rewardsToken");
    _rewardsToken = rewardsToken;
    emit RewardsTokenSet(rewardsToken);
  }

  function setRewardsQuoteToken(address quoteToken) external onlyOwner {
    require(quoteToken != address(0), "Invalid address for quoteToken");
    _rewardsQuoteToken = abi.encodePacked(quoteToken);
    emit RewardsQuoteTokenSet(quoteToken);
  }

  function setChannelId(uint32 channelId) external onlyOwner {
    require(channelId != 0, "Invalid channelId");
    _destinationChannelId = channelId;
    emit ChannelIdSet(channelId);
  }

  function setDestinationPath(uint32 path) external onlyOwner {
    require(path != 0, "Invalid destinationPath");
    _destinationPath = path;
    emit DestinationPathSet(path);
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
