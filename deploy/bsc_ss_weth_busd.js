const { chainIdByName, toBytes, isHardhat, findNearestValidTick, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSBscWethBusd';
const bundlerId = 'SS-BSC-WETH-BUSD';
const priceSlippage = 300n; // 3%

module.exports = async (hre) => {
    const { ethers, getNamedAccounts, deployments } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const chainId = chainIdByName(network.name);

    // Only run on BSC Chains
    if (chainId !== 97 && chainId !== 56) { return; }

    const routers = globals.router[chainId];
    const tokenAddress = globals.tokenAddress[chainId];
    const web3packs = await ethers.getContract('Web3PacksV2');
    const web3packsState = await ethers.getContract('Web3PacksState');

    const constructorArgs = [
      {
        weth: tokenAddress.weth,
        token0: tokenAddress.weth,
        token1: tokenAddress.busd,
        manager: web3packs.address,
        swapRouter: routers.pancakeSwapUni,
        liquidityRouter: routers.pancakeSwapV3Nft,
        poolId: toBytes(''),
        bundlerId: toBytes(bundlerId),
        slippage: priceSlippage,
        tickLower: BigInt(findNearestValidTick(60, true)),
        tickUpper: BigInt(findNearestValidTick(60, false)),
      },
      tokenAddress.busd,
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
