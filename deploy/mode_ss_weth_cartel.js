const { chainIdByName, toBytes, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSWethCartel';
const bundlerId = 'SS-WETH-CARTEL';
const priceSlippage = 300n; // 3%

module.exports = async (hre) => {
    const { ethers, getNamedAccounts, deployments } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const chainId = chainIdByName(network.name);

    const routers = globals.router[chainId];
    const tokenAddress = globals.tokenAddress[chainId];
    const web3packs = await ethers.getContract('Web3PacksV2');
    const web3packsState = await ethers.getContract('Web3PacksState');

    const constructorArgs = [
      {
        weth: tokenAddress.weth,
        token0: tokenAddress.weth,
        token1: tokenAddress.cartel,
        manager: web3packs.address,
        swapRouter: routers.velodromeV2,
        liquidityRouter: routers.velodromeV2,
        poolId: toBytes(''),
        bundlerId: toBytes(bundlerId),
        slippage: priceSlippage,
        tickLower: 100n, // Cartel/Mode is 100 Tick Spacing
        tickUpper: 200n, // Weth/Mode is 200 Tick Spacing (Standard)
      },
      tokenAddress.mode,
    ];

    //
    // Deploy Contracts
    //
    log(`\nDeploying ${bundlerContractName} Bundler...`);

    await deploy(bundlerContractName, {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    const bundler = await ethers.getContract(bundlerContractName);
    if (!isHardhat(network)) {
      await verifyContract(bundlerContractName, bundler, constructorArgs);
    }

    log(`  Registering Bundler in Web3Packs: ${bundlerId} = ${bundler.address}`);
    await web3packsState.registerBundlerId(toBytes(bundlerId), bundler.address).then(tx => tx.wait());
};

module.exports.tags = [bundlerId];
