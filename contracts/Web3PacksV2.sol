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
//  \  /\  /  __/ |_) |__) / ___/ (_| | (__|   <\__ \____\ V / / __/
//   \/  \/ \___|_.__/____/\    \__,_|\___|_|\_\___/      \_/ |_____|
//

pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./lib/BlackholePrevention.sol";
import "./interfaces/IWeb3Packs.sol";
import "./interfaces/IWeb3PacksState.sol";
import "./interfaces/IWeb3PacksVault.sol";
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
  using SafeERC20 for IERC20;

  event ChargedParticlesSet(address indexed chargedParticles);
  event ChargedStateSet(address indexed chargedState);
  event Web3PacksStateSet(address indexed web3state);
  event Web3PacksVaultSet(address indexed web3vault);
  event ProtonSet(address indexed proton);
  event PackBundled(uint256 indexed tokenId, address indexed receiver, bytes32 packType, uint256 paymentAmount);
  event PackUnbundled(uint256 indexed tokenId, address indexed receiver, uint256 ethAmount);
  event ProtocolFeeSet(uint256 fee);
  event RewardsPercentSet(uint256 max, uint256 step);
  event Web3PacksTreasurySet(address indexed treasury);

  uint256 private constant BASIS_POINTS = 10000;
  uint256 public _rewardsMax = 330;  // 3.3%
  uint256 public _rewardsStep = 30;  // 0.3%

  address public _weth;
  address public _proton;
  address public _web3state;
  address public _web3vault;
  address public _chargedParticles;
  address public _chargedState;
  address payable internal _treasury;
  uint256 public _protocolFee;

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

  receive() external payable {}


  /***********************************|
  |               Public              |
  |__________________________________*/

  function bundle(
    IWeb3PacksDefs.BundleChunk[] calldata bundleChunks,
    address[] calldata referrals,
    string calldata tokenMetaUri,
    IWeb3PacksDefs.LockState calldata lockState,
    bytes32 packType,
    address purchaser,
    uint256 paymentAmount
  )
    external
    payable
    override
    whenNotPaused
    nonReentrant
    returns(uint256 tokenId)
  {
    if (msg.value > 0) { // Payment in NATIVE
      enterWeth(msg.value);
    }
    if (paymentAmount > 0) { // Payment in WETH
      IERC20(_weth).safeTransferFrom(_msgSender(), address(this), paymentAmount);
    }

    // Total Payment Amount
    uint256 totalPayment = IERC20(_weth).balanceOf(address(this));

    // Protocol Fees
    uint256 fee = _getProtocolFee(totalPayment);
    if (fee > 0) {
      IERC20(_weth).safeTransfer(_treasury, fee);
    }

    uint256 remainingAmount = totalPayment - fee;
    uint256 rewards = _collectReferralRewards(remainingAmount, referrals);
    uint256 bundleAmount = remainingAmount - rewards;

    tokenId = _bundle(
      bundleChunks,
      tokenMetaUri,
      lockState,
      bundleAmount,
      purchaser
    );
    emit PackBundled(tokenId, purchaser, packType, totalPayment);
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

  // Primarily for Unbundling Old Packs from V1
  function unbundleUnknown(
    address payable receiver,
    address tokenAddress,
    uint256 tokenId,
    bytes32[] memory packBundles,
    bool sellAll
  )
    external
    override
    payable
    whenNotPaused
    nonReentrant
  {
    _collectFees(0);
    uint256 ethAmount = _unbundlePack(
      receiver,
      tokenAddress,
      tokenId,
      packBundles,
      sellAll
    );
    emit PackUnbundled(tokenId, receiver, ethAmount);
  }

  // NOTE: Call via "staticCall" for Balances
  function getPackBalances(address tokenAddress, uint256 tokenId) public override returns (TokenAmount[] memory) {
    return _getPackBalances(tokenAddress, tokenId);
  }

  function getPackPriceEth(uint256 tokenId) public view override returns (uint256 packPriceEth) {
    packPriceEth = IWeb3PacksState(_web3state).getPackPriceByPackId(tokenId);
  }

  function getReferralRewardsOf(address account) public view override returns (uint256 balance) {
    balance = IWeb3PacksVault(_web3vault).getReferrerBalance(account);
  }

  function claimReferralRewards(address payable account) public override nonReentrant {
    IWeb3PacksVault(_web3vault).claimReferralRewards(account);
  }


  /***********************************|
  |     Private Bundle Functions      |
  |__________________________________*/

  function _bundle(
    IWeb3PacksDefs.BundleChunk[] calldata bundleChunks,
    string calldata tokenMetaUri,
    IWeb3PacksDefs.LockState calldata lockState,
    uint256 bundleAmountWeth,
    address purchaser
  )
    internal
    returns(uint256 tokenId)
  {
    IWeb3PacksBundler bundler;

    // Mint Web3Pack NFT
    tokenId = _createBasicProton(tokenMetaUri);

    uint256 wethTotal = bundleAmountWeth;
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
      address bundlerAddress = IWeb3PacksState(_web3state).getBundlerById(chunk.bundlerId);
      if (bundlerAddress == address(0)) {
        revert BundlerNotRegistered(chunk.bundlerId);
      }
      bundler = IWeb3PacksBundler(bundlerAddress);

      // Calculate Percent
      chunkWeth = (wethTotal * chunk.percentBasisPoints) / BASIS_POINTS;

      // Send WETH to Bundler
      TransferHelper.safeTransfer(_weth, address(bundler), chunkWeth);

      // Receive Assets from Bundler
      //  If Liquidity is ERC20: nftTokenId == 0
      //  If Liquidity is ERC721: nftTokenId > 0
      (tokenAddress, amountOut, nftTokenId) = bundler.bundle(tokenId, purchaser);

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
    IWeb3PacksState(_web3state).setBundlesByPackId(tokenId, packBundlerIds);
    IWeb3PacksState(_web3state).setPackPriceByPackId(tokenId, wethTotal);

    // Set the Timelock State
    _lock(lockState, tokenId);

    // Transfer the Web3Packs NFT to the Buyer
    IBaseProton(_proton).safeTransferFrom(address(this), purchaser, tokenId);
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
    // Ensure Pack has Bundles
    bytes32[] memory bundles = IWeb3PacksState(_web3state).getBundlesByPackId(packTokenId);
    if (bundles.length == 0) {
      revert NoBundlesInPack();
    }

    // Unbundle Known Pack
    ethAmount = _unbundlePack(
      receiver,
      tokenAddress,
      packTokenId,
      bundles,
      sellAll
    );

    // Clear Bundles for Pack
    bytes32[] memory empty;
    IWeb3PacksState(_web3state).setBundlesByPackId(packTokenId, empty);
    IWeb3PacksState(_web3state).setPackPriceByPackId(packTokenId, 0);
  }

  function _unbundlePack(
    address payable receiver,
    address tokenAddress,
    uint256 packTokenId,
    bytes32[] memory packBundles,
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

    address assetTokenAddress;
    uint256 assetTokenId;
    for (uint i; i < packBundles.length; i++) {
      address bundlerAddress = IWeb3PacksState(_web3state).getBundlerById(packBundles[i]);
      if (bundlerAddress == address(0)) {
        // skip unregistered bundlers to prevent breaking unbundle
        continue;
      }
      bundler = IWeb3PacksBundler(bundlerAddress);

      // Pull Assets from NFT and send to Bundler for Unbundling
      (assetTokenAddress, assetTokenId) = bundler.getLiquidityToken(packTokenId);
      if (assetTokenId == 0) {
        _release(bundlerAddress, packTokenId, assetTokenAddress);
      } else {
        _breakBond(bundlerAddress, packTokenId, assetTokenAddress, assetTokenId);
      }

      // Unbundle current asset
      ethAmount += bundler.unbundle(receiver, packTokenId, sellAll);
    }
  }

  function _getPackBalances(address tokenAddress, uint256 tokenId) internal returns (TokenAmount[] memory) {
    IWeb3PacksBundler bundler;

    // Ensure Pack has Bundles
    bytes32[] memory bundles = IWeb3PacksState(_web3state).getBundlesByPackId(tokenId);
    uint256 bundleCount = bundles.length;
    if (bundleCount == 0) {
      revert NoBundlesInPack();
    }

    TokenAmount[] memory tokenBalances = new TokenAmount[](bundleCount);
    for (uint i; i < bundleCount; i++) {
      bytes32 bundlerId = bundles[i];
      address bundlerAddress = IWeb3PacksState(_web3state).getBundlerById(bundlerId);
      if (bundlerAddress == address(0)) {
        // skip unregistered bundlers
        continue;
      }

      // Get Liquidity Token from Bundler
      bundler = IWeb3PacksBundler(bundlerAddress);
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

  function enterWeth(uint256 amount) internal virtual {
    IWETH(_weth).deposit{value: amount}();
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

  function _getProtocolFee(uint256 totalPayment) internal view returns (uint256) {
    if (_protocolFee > 0 && totalPayment < _protocolFee) {
      revert InsufficientForFee(totalPayment, 0, _protocolFee);
    }
    return _protocolFee;
  }

  // Legacy function for payable unbundles
  function _collectFees(uint256 excludedAmount) internal {
    // Track Collected Fees
    if (_protocolFee > 0 && msg.value < (_protocolFee + excludedAmount)) {
      revert InsufficientForFee(msg.value, excludedAmount, _protocolFee);
    }
    uint256 fees = msg.value - excludedAmount;
    _treasury.sendValue(fees);
  }

  function _collectReferralRewards(
    uint256 paymentAmount,
    address[] memory referrals
  ) internal returns (uint256 fee) {
    uint256 referralAmountTotal = ((paymentAmount * _rewardsMax) / BASIS_POINTS);
    uint256[] memory referralAmounts;
    IWeb3PacksVault _vault = IWeb3PacksVault(_web3vault);

    // Calculate Referral Amounts and Distribute
    if (referrals.length > 0 && referrals[0] != address(0)) {
      referralAmounts = new uint256[](referrals.length);

      // Remove Referral Value from Funding Value
      fee = referralAmountTotal;

      if (referrals.length > 1 && referrals[1] != address(0)) {
        referralAmounts[0] = (paymentAmount * _rewardsStep) / BASIS_POINTS;
        if (referrals.length > 2 && referrals[2] != address(0)) {
          referralAmounts[1] = (paymentAmount * _rewardsStep) / BASIS_POINTS;
          referralAmounts[2] = (paymentAmount * (_rewardsMax - (_rewardsStep * 2))) / BASIS_POINTS;
        } else {
          referralAmounts[1] = (paymentAmount * (_rewardsMax - _rewardsStep)) / BASIS_POINTS;
        }
      } else {
        referralAmounts[0] = referralAmountTotal;
      }

      // Transfer Rewards to Vault Contract
      IERC20(_weth).safeTransfer(address(_vault), fee);

      // Update Referrer Balances
      _vault.updateReferrerBalances(referralAmountTotal, referrals, referralAmounts);
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

  function setWeb3PacksState(address web3state) external onlyOwner {
    require(web3state != address(0), "Invalid address for web3state");
    _web3state = web3state;
    emit Web3PacksStateSet(web3state);
  }

  function setWeb3PacksVault(address web3vault) external onlyOwner {
    require(web3vault != address(0), "Invalid address for web3vault");
    _web3vault = web3vault;
    emit Web3PacksVaultSet(web3vault);
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

  function setRewardsPercent(uint256 max, uint256 step) external onlyOwner {
    _rewardsMax = max;
    _rewardsStep = step;
    emit RewardsPercentSet(max, step);
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