import { expect } from 'chai';
import { ethers, network, getNamedAccounts } from 'hardhat';
import { BigNumber, Contract, Signer } from 'ethers';

import globals from '../js-helpers/globals';
import { _findNearestValidTick } from './utils';

import { Web3PacksV2, IWeb3PacksDefs } from '../typechain-types/contracts/Web3PacksV2';
import { ERC721Mintable } from '../typechain-types/contracts/lib/ERC721Mintable';

import IAlgebraRouterABI from '../build/contracts/contracts/interfaces/IAlgebraRouter.sol/IAlgebraRouter.json';
import INonfungiblePositionManager from '../build/contracts/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json';
import IBalancerVaultABI from '../build/contracts/contracts/interfaces/IBalancerV2Vault.sol/IBalancerV2Vault.json';

import {
  default as Charged,
  chargedStateAbi,
  protonBAbi
} from "@charged-particles/charged-js-sdk";

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
}

interface FnCallUnbundle {
  receiver?: string;
  signer?: Signer;
  tokenId: string;
  sellAll?: boolean;
}

interface FnCallUnbundleReturn {
  gasCost: BigNumber;
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


describe('Web3PacksV2', async ()=> {
  // Define contracts
  let web3packs: Web3PacksV2;
  let Proton: Contract;

  // Charged Particles SDK
  let charged: Charged;

  // Define signers
  let treasury;
  let deployer;
  let ownerSigner: Signer;
  let testSigner: Signer;
  let deployerSigner: Signer;

  let IVelodromeRouter;
  let velodromeRouter: Contract;

  let IAlgebraRouter;
  let kimRouter: Contract;

  let IBalancerV2Vault;
  let balancerVault: Contract;

  let IKimManager;
  let kimManager: Contract;

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
    // @ts-ignore
    charged = new Charged({ providers: network.provider, signer: testSigner });

    IVelodromeRouter = new ethers.utils.Interface(globals.velodromeRouterAbi);
    velodromeRouter = new Contract(routers.velodrome, IVelodromeRouter, deployerSigner);

    IAlgebraRouter = new ethers.utils.Interface(IAlgebraRouterABI.abi);
    kimRouter = new Contract(routers.kim, IAlgebraRouter, deployerSigner);

    IKimManager = new ethers.utils.Interface(INonfungiblePositionManager.abi);
    kimManager = new Contract(routers.kimNft, IKimManager, deployerSigner);

    IBalancerV2Vault = new ethers.utils.Interface(IBalancerVaultABI.abi);
    balancerVault = new Contract(routers.balancer, IBalancerV2Vault, deployerSigner);

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

    return {tokenId, gasCost};
  };

  const _callUnbundle = async ({
    receiver = deployer,
    signer = deployerSigner,
    tokenId,
    sellAll = false,
  }: FnCallUnbundle): Promise<FnCallUnbundleReturn> => {
    // Approve Web3Packs to Unbundle our Charged Particle
    const chargedState = new Contract(globals.chargedStateContractAddress, chargedStateAbi, signer);
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

    return {gasCost};
  };

  describe('Single-sided Bundlers (w/o Sell All)', () => {
    for (let i = 0; i < singleSidedBundlers.length; i++) {
      const bundler = singleSidedBundlers[i];

      it(`Bundles/Unbundles using Bundler: ${bundler.bundlerId}`, () => {
        (async (sellAll) => {
          const { deployer } = await getNamedAccounts();
          const ethPackPrice = ethers.utils.parseUnits('1', 18);

          // @ts-ignore
          const bundlerContract = await ethers.getContract(bundler.contract);
          const token1 = (await bundlerContract.getToken1())['tokenAddress'];

          // Get Balance before Transaction for Test Confirmation
          const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
            {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
          ];

          // Bundle Pack
          const { tokenId, gasCost } = await _callBundle({
            bundleChunks,
            packType: 'ECOSYSTEM',
            ethPackPrice,
          });
          const web3pack = charged.NFT(Proton.address, tokenId);

          const tokenMass = await web3pack.getMass(token1, 'generic.B');
          const tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
          expect(tokenAmount).to.be.gt(100);

          // Confirm ETH Balance
          const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
          const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
          expect(postBalance).to.eq(expectedBalance);

          // Unbundle Pack
          await _callUnbundle({ tokenId });

          // Check Receiver for Tokens
          const tokenContract = new Contract(token1, globals.erc20Abi, deployerSigner);
          const tokenBalance = await tokenContract.balanceOf(deployer);
          expect(tokenBalance).to.be.gte(tokenAmount);
        })(false);
      });
    }
  });

  describe('Single-sided Bundlers (w/ Sell All)', () => {
    for (let i = 0; i < singleSidedBundlers.length; i++) {
      const bundler = singleSidedBundlers[i];

      it(`Bundles/Unbundles using Bundler: ${bundler.bundlerId}`, () => {
        (async (sellAll) => {
          const { deployer } = await getNamedAccounts();
          const ethPackPrice = ethers.utils.parseUnits('1', 18);

          // @ts-ignore
          const bundlerContract = await ethers.getContract(bundler.contract);
          const token1 = (await bundlerContract.getToken1())['tokenAddress'];

          // Get Balance before Transaction for Test Confirmation
          const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
            {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
          ];

          // Bundle Pack
          const { tokenId, gasCost } = await _callBundle({
            bundleChunks,
            packType: 'ECOSYSTEM',
            ethPackPrice,
          });
          const web3pack = charged.NFT(Proton.address, tokenId);

          const tokenMass = await web3pack.getMass(token1, 'generic.B');
          const tokenAmount = tokenMass[network.config.chainId ?? '']?.value;
          expect(tokenAmount).to.be.gt(100);

          // Confirm ETH Balance
          const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
          const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
          expect(postBalance).to.eq(expectedBalance);

          // Unbundle Pack
          const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll: true });
          const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          // Confirm ETH Balance
          const sellAllValue = (ethPackPrice.toBigInt() * 9500n) / 10000n; // at least 95%
          const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
          expect(finalBalance).to.gte(newExpectedBalance);
        })(true);
      });
    }
  });

  describe('Liquidity-Position Bundlers (w/o Sell All)', () => {
    for (let i = 0; i < liqPosBundlers.length; i++) {
      const bundler = liqPosBundlers[i];

      it(`Bundles/Unbundles using Bundler: ${bundler.bundlerId}`, () => {
        (async (sellAll) => {
          const { deployer } = await getNamedAccounts();
          const ethPackPrice = ethers.utils.parseUnits('0.1', 18);

          // @ts-ignore
          const bundlerContract = await ethers.getContract(bundler.contract);
          const token0 = (await bundlerContract.getToken0())['tokenAddress'];
          const token1 = (await bundlerContract.getToken1())['tokenAddress'];

          // Get Balance before Transaction for Test Confirmation
          const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
            {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
          ];

          // Bundle Pack
          const {tokenId, gasCost} = await _callBundle({
            bundleChunks,
            packType: 'DEFI',
            ethPackPrice,
          });

          const web3pack = charged.NFT(Proton.address, tokenId);
          const { tokenAddress: lpTokenAddress, tokenId: lpTokenId } = await bundlerContract.getLiquidityToken(tokenId);

          // Check Liquidity Type
          let liquidityTokenAmount;
          if (lpTokenId.toBigInt() > 0n) {
            // Check Pack for Liquidity NFT
            const tokenBonds = await web3pack.getBonds('generic.B');
            const bondCount = tokenBonds[network.config.chainId ?? '']?.value;
            expect(bondCount).to.eq(1);
          } else {
            // Check Pack for Liquidity Tokens
            const tokenMass = await web3pack.getMass(lpTokenAddress, 'generic.B');
            liquidityTokenAmount = tokenMass[network.config.chainId ?? '']?.value;
            expect(liquidityTokenAmount).to.be.gt(100);
          }

          // Confirm ETH Balance
          const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
          const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
          expect(postBalance).to.eq(expectedBalance);

          // Unbundle Pack
          await _callUnbundle({ tokenId, sellAll });

          // Check Receiver for Tokens
          if (bundler.bundlerId === 'LP-WETH-MODE-8020') {
            // Governance Pack wants to Unbundle Liquidity Tokens without Exiting Position - for Voting Purposes
            const tokenContract = new Contract(lpTokenAddress, globals.erc20Abi, deployerSigner);
            const tokenBalance = await tokenContract.balanceOf(deployer);
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
        })(false);
      });
    }
  });

  describe('Liquidity-Position Bundlers (w/ Sell All)', () => {
    for (let i = 0; i < liqPosBundlers.length; i++) {
      const bundler = liqPosBundlers[i];

      it(`Bundles/Unbundles using Bundler: ${bundler.bundlerId}`, () => {
        (async (sellAll) => {
          const { deployer } = await getNamedAccounts();
          const ethPackPrice = ethers.utils.parseUnits('0.1', 18);

          // @ts-ignore
          const bundlerContract = await ethers.getContract(bundler.contract);

          // Get Balance before Transaction for Test Confirmation
          const preBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
            {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
          ];

          // Bundle Pack
          const {tokenId, gasCost} = await _callBundle({
            bundleChunks,
            packType: 'DEFI',
            ethPackPrice,
          });

          const web3pack = charged.NFT(Proton.address, tokenId);
          const { tokenAddress: lpTokenAddress, tokenId: lpTokenId } = await bundlerContract.getLiquidityToken(tokenId);

          // Check Liquidity Type
          let liquidityTokenAmount;
          if (lpTokenId.toBigInt() > 0n) {
            // Check Pack for Liquidity NFT
            const tokenBonds = await web3pack.getBonds('generic.B');
            const bondCount = tokenBonds[network.config.chainId ?? '']?.value;
            expect(bondCount).to.eq(1);
          } else {
            // Check Pack for Liquidity Tokens
            const tokenMass = await web3pack.getMass(lpTokenAddress, 'generic.B');
            liquidityTokenAmount = tokenMass[network.config.chainId ?? '']?.value;
            expect(liquidityTokenAmount).to.be.gt(100);
          }

          // Confirm ETH Balance
          const expectedBalance = preBalance - ethPackPrice.toBigInt() - globals.protocolFee.toBigInt() - gasCost.toBigInt();
          const postBalance = (await ethers.provider.getBalance(deployer)).toBigInt();
          expect(postBalance).to.eq(expectedBalance);

          // Unbundle Pack
          const { gasCost: unbundleGasCost } = await _callUnbundle({ tokenId, sellAll });
          const finalBalance = (await ethers.provider.getBalance(deployer)).toBigInt();

          // Confirm ETH Balance
          const sellAllValue = (ethPackPrice.toBigInt() * 8000n) / 10000n; // at least 80%
          const newExpectedBalance = postBalance + sellAllValue - globals.protocolFee.toBigInt() - unbundleGasCost.toBigInt();
          expect(finalBalance).to.gte(newExpectedBalance);
        })(true);
      });
    }
  });

  describe('Web3Packs Bundler Public Routines', () => {
    it('Allows external checks on Balance/Address of Tokens', () => {
      (async () => {
        const ethPackPrice = ethers.utils.parseUnits('0.1', 18);
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
        const ethPackPrice = ethers.utils.parseUnits('0.1', 18);
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
        const ethPackPrice = ethers.utils.parseUnits('0.1', 18);
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
      const ethPackPrice = ethers.utils.parseUnits('0.1', 18);
      const bundler = { bundlerId: 'SS-WETH-IONX', contract: 'SSWethIonx' };

      const bundleChunks:IWeb3PacksDefs.BundleChunkStruct[] = [
        {bundlerId: toBytes32(bundler.bundlerId), percentBasisPoints: 10000},
      ];

      // Bundle Pack
      const { tokenId } = await _callBundle({
        bundleChunks,
        packType: 'ECOSYSTEM',
        ethPackPrice,
      });

      const { tokenAddress, balance, nftTokenId } = (await web3packs.callStatic.getPackBalances(contracts.protonC, tokenId))[0];

      expect(tokenAddress).to.eq(tokenAddresses.ionx);
      expect(balance).to.be.gte(1);
      expect(nftTokenId).to.eq(0);
    });

    it('Allows external checks on Original Pack Price', async () => {
      const ethPackPrice = ethers.utils.parseUnits('0.1', 18);
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
      const originalPrice = await web3packs.callStatic.getPackPriceEth(tokenId);
      expect(originalPrice).to.gte(ethPackPrice);
    });
  });

  describe('Web3Packs Referrals', () => {
    it('Allows external checks on Referral Rewards');
    it('Allows external Claim on Rewards from Referrals');
    it('Properly Accounts for 1 Referrer');
    it('Properly Accounts for 2 Referrers');
    it('Properly Accounts for 3 Referrers');
  });

  describe('Web3Packs Custom Packs', () => {
    it('Bundles an Ecosystem Pack');
    it('Bundles a Defi Pack');
    it('Bundles a Governance Pack');
    it('Bundles an AI Pack');
  });

  describe('Web3Packs Error Tests', () => {
    it('Bundles an Ecosystem Pack');
    it('Bundles a Defi Pack');
    it('Bundles a Governance Pack');
    it('Bundles an AI Pack');
  });
});
