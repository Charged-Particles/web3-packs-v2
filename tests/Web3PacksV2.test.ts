import { expect } from 'chai';
import { ethers, network, getNamedAccounts } from 'hardhat';
import { BigNumber, Contract, Signer } from 'ethers';

import globals from '../js-helpers/globals';
import { _findNearestValidTick } from './utils';
import { Web3PacksV2, IWeb3PacksDefs } from '../typechain-types/contracts/Web3PacksV2';
import { chargedParticlesAbi, chargedStateAbi, protonBAbi } from "@charged-particles/charged-js-sdk";

interface BundleChunk extends IWeb3PacksDefs.BundleChunkStruct {}

interface FnCallBundle {
  bundleChunks: BundleChunk[];
  referrals?: string[];
  tokenMetaUri?: string;
  lockState?: { ERC20Timelock: number, ERC721Timelock: number };
  packType: string;
  ethPackPrice: BigNumber;
}

interface FnCallBundleReturn {
  tokenId: string;
  gasCost: BigNumber;
  tx: object;
}

interface FnCallUnbundle {
  receiver?: string;
  signer?: Signer;
  tokenId: string;
  sellAll?: boolean;
}

interface FnCallUnbundleReturn {
  gasCost: BigNumber;
  tx: object;
}

const toBytes32 = (text) => ethers.utils.formatBytes32String(text);

const singleSidedBundlers = [
  { bundlerId: 'SS-WETH-BMX',  contract: 'SSWethBmx' },
  { bundlerId: 'SS-WETH-ICL',  contract: 'SSWethIcl' },
  { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' },
  { bundlerId: 'SS-WETH-KIM',  contract: 'SSWethKim' },
  { bundlerId: 'SS-WETH-MODE', contract: 'SSWethMode' },
  { bundlerId: 'SS-WETH-SMD',  contract: 'SSWethSmd' },
  { bundlerId: 'SS-WETH-WMLT', contract: 'SSWethWmlt' },
  { bundlerId: 'SS-WETH-PACKY', contract: 'SSWethPacky' },
  { bundlerId: 'SS-WETH-CARTEL', contract: 'SSWethCartel' },
  { bundlerId: 'SS-WETH-GAMBL', contract: 'SSWethGambl' },
];

const liqPosBundlers = [
  { bundlerId: 'LP-WETH-IONX',  contract: 'LPWethIonx' },
  { bundlerId: 'LP-WETH-KIM',   contract: 'LPWethKim' },
  { bundlerId: 'LP-WETH-MODE',  contract: 'LPWethMode' },
  { bundlerId: 'LP-WETH-STONE', contract: 'LPWethStone' },
  { bundlerId: 'LP-WETH-USDC',  contract: 'LPWethUsdc' },
  { bundlerId: 'LP-WETH-WBTC',  contract: 'LPWethWbtc' },
  { bundlerId: 'LP-IUSD-USDC',  contract: 'LPIusdUsdc' },
  { bundlerId: 'LP-WETH-MODE-8020',  contract: 'LPWethMode8020' },
];

const ethPackPrice = ethers.utils.parseUnits('0.01', 18);

describe('Web3PacksV2', async ()=> {
  // Define contracts
  let web3packs: Web3PacksV2;
  let Proton: Contract;

  // Charged Particles
  let charged: Contract;

  // Define signers
  let treasury;
  let deployer;
  let ownerSigner: Signer;
  let testSigner: Signer;
  let deployerSigner: Signer;

  let chainId;
  let routers;
  let contracts;
  let tokenAddresses;

  beforeEach(async () => {
    const { treasury: treasuryAccount, deployer: deployerAccount } = await getNamedAccounts();
    treasury = treasuryAccount;
    deployer = deployerAccount;

    chainId = 34443;
    routers = globals.router[chainId];
    contracts = globals.contracts[chainId];
    tokenAddresses = globals.tokenAddress[chainId];

    // @ts-ignore
    web3packs = await ethers.getContract('Web3PacksV2') as Web3PacksV2;

    ownerSigner = await ethers.getSigner(treasury);
    deployerSigner = await ethers.getSigner(deployer);
    testSigner = ethers.Wallet.fromMnemonic(`${process.env.TESTNET_MNEMONIC}`.replace(/_/g, ' '));

    charged = new ethers.Contract(contracts.chargedParticles, chargedParticlesAbi, ownerSigner);
    Proton = new ethers.Contract(contracts.protonC, protonBAbi, ownerSigner);
  });

  const _callBundle = async ({
    bundleChunks = [],
    referrals = [],
    tokenMetaUri = globals.ipfsMetadata,
    lockState = { ERC20Timelock: 0, ERC721Timelock: 0 },
    packType,
    ethPackPrice,
  }: FnCallBundle): Promise<FnCallBundleReturn> => {
    const bundleFee = globals.protocolFee;

    const tokenId = await web3packs.callStatic.bundle(
      bundleChunks,
      referrals,
      tokenMetaUri,
      lockState,
      toBytes32(packType),
      ethPackPrice,
      { value: ethPackPrice.add(bundleFee) }
    );

    const mintTx = await web3packs.bundle(
      bundleChunks,
      referrals,
      tokenMetaUri,
      lockState,
      toBytes32(packType),
      ethPackPrice,
      { value: ethPackPrice.add(bundleFee) }
    );
    const txReceipt = await mintTx.wait();
    const gasCost = ethers.BigNumber.from(txReceipt.cumulativeGasUsed.toBigInt() * txReceipt.effectiveGasPrice.toBigInt());

    return { tokenId, gasCost, tx: mintTx };
  };

  const _callUnbundle = async ({
    receiver = deployer,
    signer = deployerSigner,
    tokenId,
    sellAll = false,
  }: FnCallUnbundle): Promise<FnCallUnbundleReturn> => {
    // Approve Web3Packs to Unbundle our Charged Particle
    const chargedState = new Contract(contracts.chargedState, chargedStateAbi, signer);
    await chargedState.setApprovalForAll(Proton.address, tokenId, web3packs.address).then(tx => tx.wait());

    // Unbundle Pack
    const unbundleFee = globals.protocolFee;
    const unbundleTx = await web3packs.unbundle(
      receiver,
      Proton.address,
      tokenId,
      sellAll,
      { value: unbundleFee },
    );
    const txReceipt = await unbundleTx.wait();
    const gasCost = ethers.BigNumber.from(txReceipt.cumulativeGasUsed.toBigInt() * txReceipt.effectiveGasPrice.toBigInt());

    return { gasCost, tx: unbundleTx };
  };

  const _getParticleMass = async (tokenId, assetAddress) => {
    const tokenMass = await charged.callStatic.baseParticleMass(Proton.address, tokenId, 'generic.B', assetAddress);
    return tokenMass.toBigInt();
  };

  const _getParticleBonds = async (tokenId) => {
    const tokenBonds = await charged.currentParticleCovalentBonds(Proton.address, tokenId, 'generic.B');
    return tokenBonds.toBigInt();
  };

  describe('Single-sided Bundlers', () => {
    for (let i = 0; i < singleSidedBundlers.length; i++) {
      const bundler = singleSidedBundlers[i];

      it(`Bundles using Bundler: ${bundler.bundlerId}`, async () => {
        const { deployer } = await getNamedAccounts();

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const token1 = await bundlerContract.getToken1();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        const { tokenId, gasCost, tx } = await _callBundle({
          bundleChunks,
          packType: 'ECOSYSTEM',
          ethPackPrice,
        });
        expect(tx).not.to.be.revertedWith('SwapFailed');
        expect(tx).to.emit(bundlerContract, 'SwappedTokens');

        const tokenAmount = await _getParticleMass(tokenId, token1.tokenAddress);
        expect(tokenAmount).to.be.gt(100);

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);
      });

      it(`Unbundles without Sell All: ${bundler.bundlerId}`, async () => {
        const { deployer } = await getNamedAccounts();

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const token1 = await bundlerContract.getToken1();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        const { tokenId } = await _callBundle({
          bundleChunks,
          packType: 'ECOSYSTEM',
          ethPackPrice,
        });

        const tokenAmount = await _getParticleMass(tokenId, token1.tokenAddress);

        // Unbundle Pack
        const { tx } = await _callUnbundle({ tokenId, sellAll: false });
        expect(tx).not.to.be.revertedWith('SwapFailed');

        // Check Receiver for Tokens
        const tokenContract = new Contract(token1.tokenAddress, globals.erc20Abi, deployerSigner);
        const tokenBalance = await tokenContract.balanceOf(deployer);
        expect(tokenBalance).to.be.gte(tokenAmount);
      });

      it(`Unbundles with Sell All: ${bundler.bundlerId}`, async () => {
        const { deployer } = await getNamedAccounts();

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const token1 = await bundlerContract.getToken1();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        const { tokenId } = await _callBundle({
          bundleChunks,
          packType: 'ECOSYSTEM',
          ethPackPrice,
        });

        // Confirm ETH Balance
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        // Unbundle Pack
        const { gasCost: unbundleGasCost, tx } = await _callUnbundle({ tokenId, sellAll: true });
        expect(tx).not.to.be.revertedWith('SwapFailed');

        // Confirm ETH Balance
        const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        const sellAllValue = (ethPackPrice.toBigInt() * 9000n) / 10000n; // at least 90%
        const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
        expect(finalBalance).to.gte(newExpectedBalance);
      });
    }
  });

  describe('Liquidity-Position Bundlers', () => {
    for (let i = 0; i < liqPosBundlers.length; i++) {
      const bundler = liqPosBundlers[i];

      it(`Bundles using Bundler: ${bundler.bundlerId}`, async () => {
        const { deployer } = await getNamedAccounts();

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        const {tokenId, gasCost, tx} = await _callBundle({
          bundleChunks,
          packType: 'DEFI',
          ethPackPrice,
        });
        expect(tx).not.to.be.revertedWith('SwapFailed');
        expect(tx).to.emit(bundlerContract, 'SwappedTokens');

        const { tokenAddress: lpTokenAddress, tokenId: lpTokenId } = await bundlerContract.getLiquidityToken(tokenId);

        // Check Liquidity Type
        let liquidityTokenAmount;
        if (lpTokenId.toBigInt() > 0n) {
          // Check Pack for Liquidity NFT
          const bondCount = await _getParticleBonds(tokenId);
          expect(bondCount).to.eq(1);
        } else {
          // Check Pack for Liquidity Tokens
          liquidityTokenAmount = await _getParticleMass(tokenId, lpTokenAddress);
          expect(liquidityTokenAmount).to.be.gt(100);
        }

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);
      });

      it(`Unbundles without Sell All: ${bundler.bundlerId}`, async () => {
        const { deployer } = await getNamedAccounts();

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const token0 = (await bundlerContract.getToken0())['tokenAddress'];
        const token1 = (await bundlerContract.getToken1())['tokenAddress'];

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        const {tokenId} = await _callBundle({
          bundleChunks,
          packType: 'DEFI',
          ethPackPrice,
        });

        const { tokenAddress: lpTokenAddress } = await bundlerContract.getLiquidityToken(tokenId);

        // Unbundle Pack
        const { tx } = await _callUnbundle({ tokenId, sellAll: false });
        expect(tx).not.to.be.revertedWith('SwapFailed');

        // Check Receiver for Tokens
        if (bundler.bundlerId === 'LP-WETH-MODE-8020') {
          // Governance Pack wants to Unbundle Liquidity Tokens without Exiting Position - for Voting Purposes
          const tokenContract = new Contract(lpTokenAddress, globals.erc20Abi, deployerSigner);
          const tokenBalance = await tokenContract.balanceOf(deployer);
          const liquidityTokenAmount = await _getParticleMass(tokenId, lpTokenAddress);
          expect(tokenBalance).to.be.gte(liquidityTokenAmount);
        } else {
          // Check Receiver for Tokens
          const tokenContract0 = new Contract(token0, globals.erc20Abi, deployerSigner);
          const tokenBalance0 = await tokenContract0.balanceOf(deployer);
          expect(tokenBalance0).to.be.gte(100);

          const tokenContract1 = new Contract(token1, globals.erc20Abi, deployerSigner);
          const tokenBalance1 = await tokenContract1.balanceOf(deployer);
          expect(tokenBalance1).to.be.gte(100);
        }
      });

      it(`Unbundles with Sell All: ${bundler.bundlerId}`, (done) => {
        (async (sellAll) => {
          const { deployer } = await getNamedAccounts();

          const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
            {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
          ];

          // Bundle Pack
          const {tokenId, gasCost} = await _callBundle({
            bundleChunks,
            packType: 'DEFI',
            ethPackPrice,
          });

          const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          // Unbundle Pack
          const { gasCost: unbundleGasCost, tx } = await _callUnbundle({ tokenId, sellAll });
          expect(tx).not.to.be.revertedWith('SwapFailed');

          // Confirm ETH Balance
          const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
          const sellAllValue = (ethPackPrice.toBigInt() * 8000n) / 10000n; // at least 80%
          const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
          expect(finalBalance).to.gte(newExpectedBalance);

          done();
        })(true);
      });
    }
  });

  describe('Web3Packs Bundler Public Routines', () => {
    it('Allows external checks on Balance/Address of Tokens', () => {
      (async () => {
        const bundler = { bundlerId: 'LP-IUSD-USDC', contract: 'LPIusdUsdc' };

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        // Bundle Pack
        await _callBundle({
          bundleChunks,
          packType: 'DEFI',
          ethPackPrice,
        });

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const token0 = (await bundlerContract.getToken0())['tokenAddress'];
        const token1 = (await bundlerContract.getToken1())['tokenAddress'];
        const tokenBalance0 = await bundlerContract.getBalanceToken0();
        const tokenBalance1 = await bundlerContract.getBalanceToken1();

        expect(token0).to.eq(tokenAddresses.iusd);
        expect(token1).to.eq(tokenAddresses.usdc);
        expect(tokenBalance0).to.gte(1);
        expect(tokenBalance1).to.gte(1);
      })();
    });

    it('Allows external checks on Liquidity Token', () => {
      (async () => {
        const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const { tokenAdddress, tokenId } = await bundlerContract.getLiquidityToken();
        expect(tokenAdddress).to.eq(tokenAddresses.ionx);
        expect(tokenId).to.eq(0);
      })();
    });

    it('Allows external Quotes for Primary Token for Swaps', () => {
      (async () => {
        const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

        // @ts-ignore
        const bundlerContract = await ethers.getContract(bundler.contract);
        const amountOut = await bundlerContract.quoteSwap({ value: ethPackPrice });
        expect(amountOut).to.be.gte(1);
      })();
    });
  });

  describe('Web3Packs Public Routines', () => {
    it('Collects Fees properly', () => {
      (async () => {
        const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
        ];

        const treasuryBalanceBefore = (await ethers.provider.getBalance(treasury)).toBigInt();

        // Bundle Pack
        await _callBundle({
          bundleChunks,
          packType: 'ECOSYSTEM',
          ethPackPrice,
        });

        const treasuryBalanceAfter = (await ethers.provider.getBalance(treasury)).toBigInt();
        expect(treasuryBalanceAfter - treasuryBalanceBefore).to.be.gte(globals.protocolFee);
      })();
    });

    it('Allows external checks on Current Pack Balances', async () => {
      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32('SS-WETH-IONX'), percentBasisPoints: 3400},
        {bundlerId: toBytes32('SS-WETH-MODE'), percentBasisPoints: 3300},
        {bundlerId: toBytes32('SS-WETH-SMD'),  percentBasisPoints: 3300},
      ];

      // Bundle Pack
      const { tokenId } = await _callBundle({
        bundleChunks,
        packType: 'ECOSYSTEM',
        ethPackPrice: ethers.utils.parseUnits('0.001', 18),
      });

      const balances = (await web3packs.callStatic.getPackBalances(contracts.protonC, tokenId));

      // IONX
      expect(balances[0].tokenAddress).to.eq(tokenAddresses.ionx);
      expect(balances[0].balance).to.be.gte(1);
      expect(balances[0].nftTokenId).to.eq(0);

      // MODE
      expect(balances[1].tokenAddress).to.eq(tokenAddresses.mode);
      expect(balances[1].balance).to.be.gte(1);
      expect(balances[1].nftTokenId).to.eq(0);

      // SMD
      expect(balances[2].tokenAddress).to.eq(tokenAddresses.smd);
      expect(balances[2].balance).to.be.gte(1);
      expect(balances[2].nftTokenId).to.eq(0);
    });

    it('Allows external checks on Original Pack Price', async () => {
      const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
      ];

      // Bundle Pack
      const { tokenId } = await _callBundle({
        bundleChunks,
        packType: 'DEFI',
        ethPackPrice,
      });

      // @ts-ignore
      const originalPrice = await web3packs.getPackPriceEth(tokenId);
      expect(originalPrice).to.gte(ethPackPrice);
    });
  });

  describe('Web3Packs Referrals', () => {
    it('Properly Accounts for 1 Referrer', async () => {
      const { user1 } = await getNamedAccounts();
      const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
      ];

      const referrals = [ user1 ];
      const expectedRewards1 = (ethPackPrice.toBigInt() * 330n) / 10000n;

      // Bundle Pack
      await _callBundle({
        bundleChunks,
        referrals,
        packType: 'DEFI',
        ethPackPrice,
      });

      const referralRewards = await web3packs.getReferralRewardsOf(user1);
      expect(referralRewards).to.gte(expectedRewards1);
    });

    it('Properly Accounts for 2 Referrers', async () => {
      const { user1, user2 } = await getNamedAccounts();
      const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
      ];

      const referrals = [ user1, user2 ];
      const expectedRewards1 = (ethPackPrice.toBigInt() * 30n) / 10000n;
      const expectedRewards2 = (ethPackPrice.toBigInt() * 300n) / 10000n;

      // Bundle Pack
      await _callBundle({
        bundleChunks,
        referrals,
        packType: 'DEFI',
        ethPackPrice,
      });

      const referralRewards1 = await web3packs.getReferralRewardsOf(user1);
      expect(referralRewards1).to.gte(expectedRewards1);

      const referralRewards2 = await web3packs.getReferralRewardsOf(user2);
      expect(referralRewards2).to.gte(expectedRewards2);
    });

    it('Properly Accounts for 3 Referrers', async () => {
      const { user1, user2, user3 } = await getNamedAccounts();
      const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
      ];

      const referrals = [ user1, user2, user3 ];
      const expectedRewards1 = (ethPackPrice.toBigInt() * 30n) / 10000n;
      const expectedRewards2 = (ethPackPrice.toBigInt() * 30n) / 10000n;
      const expectedRewards3 = (ethPackPrice.toBigInt() * 270n) / 10000n;

      // Bundle Pack
      await _callBundle({
        bundleChunks,
        referrals,
        packType: 'DEFI',
        ethPackPrice,
      });

      const referralRewards1 = await web3packs.getReferralRewardsOf(user1);
      expect(referralRewards1).to.gte(expectedRewards1);

      const referralRewards2 = await web3packs.getReferralRewardsOf(user2);
      expect(referralRewards2).to.gte(expectedRewards2);

      const referralRewards3 = await web3packs.getReferralRewardsOf(user3);
      expect(referralRewards3).to.gte(expectedRewards3);
    });
  });

  describe('Web3Packs Custom Packs', () => {
    it('Bundles/Unbundles an Ecosystem Pack', () => {
      (async (sellAll) => {
        const { deployer } = await getNamedAccounts();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          { bundlerId: toBytes32('SS-WETH-IONX'), percentBasisPoints: 2000 },
          { bundlerId: toBytes32('SS-WETH-KIM'),  percentBasisPoints: 2000 },
          { bundlerId: toBytes32('SS-WETH-MODE'), percentBasisPoints: 2000 },
          { bundlerId: toBytes32('SS-WETH-BMX'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('SS-WETH-ICL'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('SS-WETH-SMD'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('SS-WETH-WMLT'), percentBasisPoints: 1000 },
        ];

        // Bundle Pack
        const { tokenId, gasCost } = await _callBundle({
          bundleChunks,
          packType: 'ECOSYSTEM',
          ethPackPrice,
        });
        const particle = charged.NFT(Proton.address, tokenId);

        let tokenMass = await particle.getMass(tokenAddresses.ionx, 'generic.B');
        let tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.kim, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.mode, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.bmx, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.icl, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.smd, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.wmlt, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);

        // Unbundle Pack
        const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll });
        const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        // Confirm ETH Balance
        const sellAllValue = (ethPackPrice.toBigInt() * 9000n) / 10000n; // at least 90%
        const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
        expect(finalBalance).to.gte(newExpectedBalance);
      })(true);
    });

    it('Bundles/Unbundles a Defi Pack', () => {
      (async (sellAll) => {
        const { deployer } = await getNamedAccounts();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          { bundlerId: toBytes32('LP-WETH-IONX'),  percentBasisPoints: 2500 },
          { bundlerId: toBytes32('LP-WETH-KIM'),   percentBasisPoints: 2500 },
          { bundlerId: toBytes32('LP-WETH-MODE'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('LP-WETH-STONE'), percentBasisPoints: 1000 },
          { bundlerId: toBytes32('LP-WETH-USDC'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('LP-WETH-WBTC'),  percentBasisPoints: 1000 },
          { bundlerId: toBytes32('LP-IUSD-USDC'),  percentBasisPoints: 1000 },
        ];

        // Bundle Pack
        const { tokenId, gasCost } = await _callBundle({
          bundleChunks,
          packType: 'DEFI',
          ethPackPrice,
        });
        const particle = charged.NFT(Proton.address, tokenId);

        // Check Pack for Liquidity NFTs
        const tokenBonds = await particle.getBonds('generic.B');
        const bondCount = tokenBonds[network.config.chainId ?? '']?.value;
        expect(bondCount).to.eq(7);

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);

        // Unbundle Pack
        const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll });
        const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        // Confirm ETH Balance
        const sellAllValue = (ethPackPrice.toBigInt() * 9000n) / 10000n; // at least 90%
        const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
        expect(finalBalance).to.gte(newExpectedBalance);
      })(true);
    });

    it('Bundles/Unbundles a Governance Pack', () => {
      (async (sellAll) => {
        const { deployer } = await getNamedAccounts();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          { bundlerId: toBytes32('SS-WETH-IONX'),  percentBasisPoints: 300 },
          { bundlerId: toBytes32('SS-WETH-MODE'),  percentBasisPoints: 4850 },
          { bundlerId: toBytes32('LP-WETH-MODE-8020'),  percentBasisPoints: 4850 },
        ];

        // Bundle Pack
        const { tokenId, gasCost } = await _callBundle({
          bundleChunks,
          packType: 'GOVERNANCE',
          ethPackPrice,
        });
        const particle = charged.NFT(Proton.address, tokenId);

        // @ts-ignore
        const bundlerContract = await ethers.getContract('LpWethMode8020');
        const { tokenAdddress: lpTokenAddress } = await bundlerContract.getLiquidityToken();

        // Check Pack for Liquidity NFTs
        const tokenBonds = await particle.getBonds('generic.B');
        const bondCount = tokenBonds[network.config.chainId ?? '']?.value;
        expect(bondCount).to.eq(1);

        // Check Pack for Liquidity Tokens
        let tokenMass = await particle.getMass(tokenAddresses.ionx, 'generic.B');
        let tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(lpTokenAddress, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);

        // Unbundle Pack
        const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll });
        const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        // Confirm ETH Balance
        const sellAllValue = (ethPackPrice.toBigInt() * 9000n) / 10000n; // at least 90%
        const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
        expect(finalBalance).to.gte(newExpectedBalance);
      })(true);
    });

    it('Bundles/Unbundles an AI Pack', () => {
      (async (sellAll) => {
        const { deployer } = await getNamedAccounts();

        // Get Balance before Transaction for Test Confirmation
        const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
          { bundlerId: toBytes32('SS-WETH-PACKY'),  percentBasisPoints: 3400 },
          { bundlerId: toBytes32('SS-WETH-CARTEL'), percentBasisPoints: 3300 },
          { bundlerId: toBytes32('SS-WETH-GAMBL'),  percentBasisPoints: 3300 },
        ];

        // Bundle Pack
        const { tokenId, gasCost } = await _callBundle({
          bundleChunks,
          packType: 'AI',
          ethPackPrice,
        });
        const particle = charged.NFT(Proton.address, tokenId);

        // Check Pack for Tokens
        let tokenMass = await particle.getMass(tokenAddresses.packy, 'generic.B');
        let tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.cartel, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        tokenMass = await particle.getMass(tokenAddresses.gambl, 'generic.B');
        tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
        expect(tokenAmount).to.be.gt(100);

        // Confirm ETH Balance
        const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
        const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
        expect(postBalance).to.eq(expectedBalance);

        // Unbundle Pack
        const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll });
        const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

        // Confirm ETH Balance
        const sellAllValue = (ethPackPrice.toBigInt() * 9000n) / 10000n; // at least 90%
        const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
        expect(finalBalance).to.gte(newExpectedBalance);
      })(true);
    });
  });
});
