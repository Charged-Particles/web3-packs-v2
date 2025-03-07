const { chainIdByName, toBytes, isHardhat, log } = require('../js-helpers/utils');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSWethBmx';
const bundlerId = 'SS-WETH-BMX';

module.exports = async (hre) => {
    const { ethers, getNamedAccounts, deployments } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const chainId = chainIdByName(network.name);
    console.log('chainId ', chainId);

    const routers = globals.router[chainId];
    const tokenAddress = globals.tokenAddress[chainId];
    const web3packs = await ethers.getContract('Web3PacksV2');

    const constructorArgs = [
      {
        weth: tokenAddress.weth,
        token0: tokenAddress.weth,
        token1: tokenAddress.bmx,
        manager: web3packs.address,
        router: routers.velodrome,
        poolId: toBytes(''),
        bundlerId: toBytes(bundlerId),
        tickLower: 0,
        tickUpper: 0,
      },
      tokenAddress.usdc,
      tokenAddress.wmlt,
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
    await web3packs.registerBundlerId(toBytes(bundlerId), bundler.address).then(tx => tx.wait());
};

module.exports.tags = [bundlerId];
