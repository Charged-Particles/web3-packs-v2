const { chainIdByName, toBytes, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSWethSmd';
const bundlerId = 'SS-WETH-SMD';
const priceSlippage = 900n; // 9% as per: https://medium.com/@conshiptrack/how-to-fix-insufficient-output-amount-error-in-pancakeswap-7ad70a4f99c8

module.exports = async (hre) => {
    const { ethers, getNamedAccounts, deployments } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const chainId = chainIdByName(network.name);

    const quoters = globals.quoter[chainId];
    const routers = globals.router[chainId];
    const tokenAddress = globals.tokenAddress[chainId];
    const web3packs = await ethers.getContract('Web3PacksV2');

    const constructorArgs = [{
      weth: tokenAddress.weth,
      token0: tokenAddress.weth,
      token1: tokenAddress.smd,
      manager: web3packs.address,
      swapQuoter: quoters.swapMode,
      swapRouter: routers.swapMode,
      liquidityRouter: routers.swapMode,
      poolId: toBytes(''),
      bundlerId: toBytes(bundlerId),
      slippage: priceSlippage,
      tickLower: BigInt(findNearestValidTick(60, true)),
      tickUpper: BigInt(findNearestValidTick(60, false)),
    }];

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
    await web3packs.registerBundlerId(toBytes(bundlerId), bundler.address).then(tx => tx.wait());
};

module.exports.tags = [bundlerId];
