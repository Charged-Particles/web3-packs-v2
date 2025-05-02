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
  event RewardsTokenSet(address indexed rewardsToken);
  event ZkgmSet(address indexed zkgm);

  IZkgm public _zkgm;
  address public _rewardsToken;
  address public _web3packs;
  address public _web3packsVault;
  uint32 public _destinationChannelId;

  constructor(
    address web3packs,
    address web3packsVault,
    address rewardsToken,
    address zkgm
  ) Ownable() {
    require(web3packs != address(0), "Invalid address for web3packs");
    require(web3packsVault != address(0), "Invalid address for vault");
    require(rewardsToken != address(0), "Invalid address for rewardsToken");
    require(zkgm != address(0), "Invalid address for zkgm");
    _web3packs = web3packs;
    _web3packsVault = web3packsVault;
    _rewardsToken = rewardsToken;
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
    uint64 timeoutTimestamp = uint64(block.timestamp + 60);

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
      timeoutTimestamp,
      0,          // block timeout [Optional]
      bytes32(0), // salt,
      instructions
    );
  }

  function _serializeInstructions(
    uint256 referralAmountTotal,
    address[] calldata referrers,
    uint256[] calldata amounts
  ) internal returns (Instruction memory batchInstrunction) {
    Instruction[] memory instructions = new Instruction[](2);

    // Create fungible asset order instruction
    instructions[0] = _getTransferInstruction(referralAmountTotal);

    // Create Contract Call Instruction
    instructions[1] = _getUpdateInstruction(referralAmountTotal, referrers, amounts);

    // Create Batch Instruction
    batchInstrunction = ZkgmLib.makeBatch(instructions);
  }

  function _getTransferInstruction(uint256 referralAmountTotal) internal returns (Instruction memory orderInstrunction) {
    bytes memory vault = abi.encodePacked(_web3packsVault);
    bytes memory quoteToken = abi.encodePacked(address(0)); // TODO

    // Create fungible asset order instruction
    orderInstrunction = _zkgm.makeFungibleAssetOrder(
      0,
      _destinationChannelId,
      msg.sender,
      vault,                // receiver,
      _rewardsToken,        // baseToken,
      referralAmountTotal,  // baseAmount,
      quoteToken,           // quoteToken,
      referralAmountTotal   // quoteAmount
    );
  }

  function _getUpdateInstruction(
    uint256 referralAmountTotal,
    address[] calldata referrers,
    uint256[] calldata amounts
  ) internal returns (Instruction memory updateInstrunction) {
    bytes memory vault = abi.encodePacked(_web3packsVault);

    // Create Contract Call Instruction
    updateInstrunction = ZkgmLib.makeMultiplexCall(
      msg.sender,
      false, // isEureka (IBC-style callbacks)
      vault,
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
    require(web3packsVault != address(0), "Invalid address for vault");
    _web3packsVault = web3packsVault;
    emit Web3PacksVaultSet(web3packsVault);
  }

  function setRewardsToken(address rewardsToken) external onlyOwner {
    require(rewardsToken != address(0), "Invalid address for rewardsToken");
    _rewardsToken = rewardsToken;
    emit RewardsTokenSet(rewardsToken);
  }

  function setZkgm(address zkgm) external onlyOwner {
    require(zkgm != address(0), "Invalid address for zkgm");
    _zkgm = IZkgm(zkgm);
    emit ZkgmSet(zkgm);
  }

  function setChannelId(uint32 channelId) external onlyOwner {
    _destinationChannelId = channelId;
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
