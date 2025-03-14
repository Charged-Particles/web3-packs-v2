// SPDX-License-Identifier: MIT

// Web3PacksV2.sol
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
//
//  __    __     _    _____   ___           _                   ____
// / / /\ \ \___| |__|___ /  / _ \__ _  ___| | _____     /\   /\___ \
// \ \/  \/ / _ \ '_ \ |_ \ / /_)/ _` |/ __| |/ / __|____\ \ / / __) |
//  \  /\  /  __/ |_) |__) / ___/ (_| | (__|   <\__ \_____\ V / / __/
//   \/  \/ \___|_.__/____/\/    \__,_|\___|_|\_\___/      \_/ |_____|
//

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./lib/BlackholePrevention.sol";
import "./interfaces/IWeb3Packs.sol";
import "./interfaces/IWeb3PacksDefs.sol";
import "./interfaces/IWeb3PacksBundler.sol";
import "./interfaces/IChargedState.sol";
import "./interfaces/IChargedParticles.sol";
import "./interfaces/IBaseProton.sol";

contract Web3PacksV2 is
  IWeb3Packs,
  Ownable,
  Pausable,
  BlackholePrevention,
  ReentrancyGuard
{
  using Address for address payable;

  event ChargedParticlesSet(address indexed chargedParticles);
  event ChargedStateSet(address indexed chargedState);
  event ProtonSet(address indexed proton);
  event PackBundled(uint256 indexed tokenId, address indexed receiver, bytes32 packType, uint256 ethPackPrice);
  event PackUnbundled(uint256 indexed tokenId, address indexed receiver, uint256 ethAmount);
  event ProtocolFeeSet(uint256 fee);
  event Web3PacksTreasurySet(address indexed treasury);
  event BundlerRegistered(address indexed bundlerAddress, bytes32 bundlerId);
  event BalanceClaimed(address indexed account, uint256 balance);

  uint256 private constant BASIS_POINTS = 10000;

  address public _weth;
  address public _proton;
  address public _chargedParticles;
  address public _chargedState;
  address payable internal _treasury;
  uint256 public _protocolFee;

  mapping (bytes32 => address) public _bundlersById;
  mapping (uint256 => uint256) internal _packPriceByPackId;
  mapping (uint256 => bytes32[]) internal _bundlesByPackId;
  mapping (address => uint256) internal _referrerBalance;

  // Charged Particles Wallet Managers
  string public _cpWalletManager = "generic.B";
  string public _cpBasketManager = "generic.B";

  constructor(
    address weth,
    address proton,
    address chargedParticles,
    address chargedState
  ) {
    _weth = weth;
    _proton = proton;
    _chargedParticles = chargedParticles;
    _chargedState = chargedState;
  }


  /***********************************|
  |               Public              |
  |__________________________________*/

  function bundle(
    IWeb3PacksDefs.BundleChunk[] calldata bundleChunks,
    address[] calldata referrals,
    string calldata tokenMetaUri,
    IWeb3PacksDefs.LockState calldata lockState,
    bytes32 packType,
    uint256 ethPackPrice
  )
    external
    override
    payable
    whenNotPaused
    nonReentrant
    returns(uint256 tokenId)
  {
    _collectFees(ethPackPrice);
    uint256 rewards = _calculateReferralRewards(ethPackPrice, referrals);
    tokenId = _bundle(
      bundleChunks,
      tokenMetaUri,
      lockState,
      ethPackPrice - rewards
    );
    emit PackBundled(tokenId, _msgSender(), packType, ethPackPrice);
  }

  function unbundle(
    address payable receiver,
    address tokenAddress,
    uint256 tokenId,
    bool sellAll
  )
    external
    override
    payable
    whenNotPaused
    nonReentrant
  {
    _collectFees(0);
    uint256 ethAmount = _unbundle(
      receiver,
      tokenAddress,
      tokenId,
      sellAll
    );
    emit PackUnbundled(tokenId, receiver, ethAmount);
  }

  // NOTE: Call via "staticCall" for Balances
  function getPackBalances(address tokenAddress, uint256 tokenId) public override returns (TokenAmount[] memory) {
    return _getPackBalances(tokenAddress, tokenId);
  }

  function getPackPriceEth(uint256 tokenId) public view override returns (uint256 packPriceEth) {
    packPriceEth = _packPriceByPackId[tokenId];
  }

  function getReferralRewardsOf(address account) public view override returns (uint256 balance) {
    balance = _referrerBalance[account];
  }

  function claimReferralRewards(address payable account) public override nonReentrant {
    uint256 balance = _referrerBalance[account];
    if (address(this).balance >= balance) {
      account.sendValue(balance);
      emit BalanceClaimed(account, balance);
    }
  }


  /***********************************|
  |     Private Bundle Functions      |
  |__________________________________*/

  function _bundle(
    IWeb3PacksDefs.BundleChunk[] calldata bundleChunks,
    string calldata tokenMetaUri,
    IWeb3PacksDefs.LockState calldata lockState,
    uint256 ethPackPrice
  )
    internal
    returns(uint256 tokenId)
  {
    IWeb3PacksBundler bundler;

    // Mint Web3Pack NFT
    tokenId = _createBasicProton(tokenMetaUri);

    // Wrap ETH for WETH
    IWETH(_weth).deposit{value: ethPackPrice}();
    uint256 wethTotal = IERC20(_weth).balanceOf(address(this));
    uint256 chunkWeth;

    // Returned from Each Bundle:
    address tokenAddress;
    uint256 amountOut;
    uint256 nftTokenId;

    // Iterate over each Bundle
    bytes32[] memory packBundlerIds = new bytes32[](bundleChunks.length);
    for (uint256 i; i < bundleChunks.length; i++) {
      IWeb3PacksDefs.BundleChunk memory chunk = bundleChunks[i];
      packBundlerIds[i] = chunk.bundlerId; // track bundlerIds per pack

      // Ensure Bundler is Registered
      if (_bundlersById[chunk.bundlerId] == address(0)) {
        revert BundlerNotRegistered(chunk.bundlerId);
      }
      bundler = IWeb3PacksBundler(_bundlersById[chunk.bundlerId]);

      // Calculate Percent
      chunkWeth = (wethTotal * chunk.percentBasisPoints) / BASIS_POINTS;

      // Send WETH to Bundler
      TransferHelper.safeTransfer(_weth, address(bundler), chunkWeth);

      // Receive Assets from Bundler
      //  If Liquidity is ERC20: nftTokenId == 0
      //  If Liquidity is ERC721: nftTokenId > 0
      (tokenAddress, amountOut, nftTokenId) = bundler.bundle(tokenId, _msgSender());

      // Deposit the Assets into the Web3Packs NFT
      if (nftTokenId == 0) {
        _energize(tokenId, tokenAddress, amountOut);
        emit BundledERC20(tokenAddress, amountOut);
      } else {
        _bond(tokenId, tokenAddress, nftTokenId);
        emit BundledERC721(tokenAddress, nftTokenId);
      }
    }

    // Track Pack Data
    _bundlesByPackId[tokenId] = packBundlerIds;
    _packPriceByPackId[tokenId] = ethPackPrice;

    // Set the Timelock State
    _lock(lockState, tokenId);

    // Transfer the Web3Packs NFT to the Buyer
    IBaseProton(_proton).safeTransferFrom(address(this), _msgSender(), tokenId);
  }

  function _unbundle(
    address payable receiver,
    address tokenAddress,
    uint256 packTokenId,
    bool sellAll
  )
    internal
    returns (uint ethAmount)
  {
    IWeb3PacksBundler bundler;

    // Verify Ownership
    address owner = IERC721(tokenAddress).ownerOf(packTokenId);
    if (_msgSender() != owner) {
      revert NotOwnerOrApproved();
    }

    // Ensure Pack has Bundles
    if (_bundlesByPackId[packTokenId].length == 0) {
      revert NoBundlesInPack();
    }

    address assetTokenAddress;
    uint256 assetTokenId;
    for (uint i; i < _bundlesByPackId[packTokenId].length; i++) {
      bytes32 bundlerId = _bundlesByPackId[packTokenId][i];
      if (_bundlersById[bundlerId] == address(0)) {
        // skip unregistered bundlers to prevent breaking unbundle
        continue;
      }
      bundler = IWeb3PacksBundler(_bundlersById[bundlerId]);

      // Pull Assets from NFT and send to Bundler for Unbundling
      (assetTokenAddress, assetTokenId) = bundler.getLiquidityToken(packTokenId);
      if (assetTokenId == 0) {
        _release(_bundlersById[bundlerId], packTokenId, assetTokenAddress);
      } else {
        _breakBond(_bundlersById[bundlerId], packTokenId, assetTokenAddress, assetTokenId);
      }

      // Unbundle current asset
      ethAmount += bundler.unbundle(receiver, packTokenId, sellAll);
    }

    // Clear Bundles for Pack
    delete _bundlesByPackId[packTokenId];
    delete _packPriceByPackId[packTokenId];
  }

  function _getPackBalances(address tokenAddress, uint256 tokenId) internal returns (TokenAmount[] memory) {
    IWeb3PacksBundler bundler;

    // Ensure Pack has Bundles
    if (_bundlesByPackId[tokenId].length == 0) {
      revert NoBundlesInPack();
    }

    uint256 bundleCount = _bundlesByPackId[tokenId].length;
    TokenAmount[] memory tokenBalances = new TokenAmount[](bundleCount);
    for (uint i; i < bundleCount; i++) {
      bytes32 bundlerId = _bundlesByPackId[tokenId][i];
      if (_bundlersById[bundlerId] == address(0)) {
        // skip unregistered bundlers
        continue;
      }

      // Get Liquidity Token from Bundler
      bundler = IWeb3PacksBundler(_bundlersById[bundlerId]);
      (address assetTokenAddress, uint256 assetTokenId) = bundler.getLiquidityToken(tokenId);
      bool isNft = (assetTokenId > 0);

      // Get Balance of NFT from Charged Particles
      uint256 assetBalance = isNft ? 1 : _getMass(tokenAddress, tokenId, assetTokenAddress);

      // Track Token Balances
      tokenBalances[i] = TokenAmount({
        tokenAddress: assetTokenAddress,
        balance: assetBalance,
        nftTokenId: assetTokenId
      });
    }
    return tokenBalances;
  }

  /***********************************|
  |     Private Charged Functions     |
  |__________________________________*/

  function _createBasicProton(
    string memory tokenMetadataUri
  )
    internal
    returns (uint256 mintedTokenId)
  {
    // Mint Web3Packs NFT (Charged-Particles ProtonC)
    mintedTokenId = IBaseProton(_proton).createBasicProton(
      address(this),
      address(this),
      tokenMetadataUri
    );
  }

  function _energize(
    uint256 packTokenId,
    address assetTokenAddress,
    uint256 assetTokenAmount
  )
    internal
  {
    if (assetTokenAmount == 0) {
      assetTokenAmount = IERC20(assetTokenAddress).balanceOf(address(this));
    }

    TransferHelper.safeApprove(
      assetTokenAddress,
      address(_chargedParticles),
      assetTokenAmount
    );

    IChargedParticles(_chargedParticles).energizeParticle(
      _proton,
      packTokenId,
      _cpWalletManager,
      assetTokenAddress,
      assetTokenAmount,
      address(this)
    );
  }

  function _release(
    address receiver,
    uint256 packTokenId,
    address assetTokenAddress
  )
    internal
  {
    IChargedParticles(_chargedParticles).releaseParticle(
      receiver,
      _proton,
      packTokenId,
      _cpWalletManager,
      assetTokenAddress
    );
  }

  function _bond(
    uint256 packTokenId,
    address nftTokenAddress,
    uint256 nftTokenId
  )
    internal
  {
    IERC721(nftTokenAddress).setApprovalForAll(_chargedParticles, true);

    IChargedParticles(_chargedParticles).covalentBond(
      _proton,
      packTokenId,
      _cpBasketManager,
      nftTokenAddress,
      nftTokenId,
      1
    );
  }

  function _breakBond(
    address receiver,
    uint256 packTokenId,
    address nftTokenAddress,
    uint256 nftTokenId
  )
    internal
  {
    IChargedParticles(_chargedParticles).breakCovalentBond(
      receiver,
      _proton,
      packTokenId,
      _cpBasketManager,
      nftTokenAddress,
      nftTokenId,
      1
    );
  }

  function _lock(LockState calldata lockState, uint256 tokenId) internal {
    if(lockState.ERC20Timelock > 0) {
      IChargedState(_chargedState).setReleaseTimelock(
        _proton,
        tokenId,
        lockState.ERC20Timelock
      );
    }

    if(lockState.ERC721Timelock > 0) {
      IChargedState(_chargedState).setBreakBondTimelock(
        _proton,
        tokenId,
        lockState.ERC721Timelock
      );
    }
  }

  function _getMass(address tokenAddress, uint256 tokenId, address assetTokenAddress) internal returns (uint256 assetMass) {
    /// @dev "baseParticleMass" is not a "view" function; call via "callStatic"
    assetMass = IChargedParticles(_chargedParticles)
      .baseParticleMass(tokenAddress, tokenId, _cpWalletManager, assetTokenAddress);
  }

  function _collectFees(uint256 excludedAmount) internal {
    // Track Collected Fees
    if (_protocolFee > 0 && msg.value < (_protocolFee + excludedAmount)) {
      revert InsufficientForFee(msg.value, excludedAmount, _protocolFee);
    }
    uint256 fees = msg.value - excludedAmount;
    _treasury.sendValue(fees);
  }

  function _calculateReferralRewards(
    uint256 ethPackPrice,
    address[] memory referrals
  ) internal returns (uint256 fee) {
    uint256 referralAmountTotal = ((ethPackPrice * 330) / BASIS_POINTS);  // 3.3%

    // Calculate Referral Amounts and Distribute
    if (referrals.length > 0 && referrals[0] != address(0)) {
      // Remove Referral Value from Funding Value
      fee = referralAmountTotal;

      if (referrals.length > 1 && referrals[1] != address(0)) {
        if (referrals.length > 2 && referrals[2] != address(0)) {
          _referrerBalance[referrals[0]] += ((ethPackPrice * 30) / BASIS_POINTS);  // 0.3%
          _referrerBalance[referrals[1]] += ((ethPackPrice * 30) / BASIS_POINTS);  // 0.3%
          _referrerBalance[referrals[2]] += ((ethPackPrice * 270) / BASIS_POINTS); // 2.7%
        } else {
          _referrerBalance[referrals[0]] += ((ethPackPrice * 30) / BASIS_POINTS);  // 0.3%
          _referrerBalance[referrals[1]] += ((ethPackPrice * 300) / BASIS_POINTS);  // 3.0%
        }
      } else {
        _referrerBalance[referrals[0]] += referralAmountTotal;  // 3.3%
      }
    }
  }

  /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

  /**
    * @dev Setup the ChargedParticles Interface
  */
  function setChargedParticles(address chargedParticles) external onlyOwner {
    require(chargedParticles != address(0), "Invalid address for chargedParticles");
    _chargedParticles = chargedParticles;
    emit ChargedParticlesSet(chargedParticles);
  }

  function setChargedState(address chargedState) external onlyOwner {
    require(chargedState != address(0), "Invalid address for chargedState");
    _chargedState = chargedState;
    emit ChargedStateSet(chargedState);
  }

  function setProton(address proton) external onlyOwner {
    require(proton != address(0), "Invalid address for proton");
    _proton = proton;
    emit ProtonSet(proton);
  }

  function setTreasury(address payable treasury) external onlyOwner {
    require(treasury != address(0), "Invalid address for treasury");
    _treasury = treasury;
    emit Web3PacksTreasurySet(treasury);
  }

  function setProtocolFee(uint256 fee) external onlyOwner {
    _protocolFee = fee;
    emit ProtocolFeeSet(fee);
  }

  function registerBundlerId(bytes32 bundlerId, address bundlerAddress) external onlyOwner {
    _bundlersById[bundlerId] = bundlerAddress;
    emit BundlerRegistered(bundlerAddress, bundlerId);
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
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

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns(bytes4) {
    return this.onERC721Received.selector;
  }
}
