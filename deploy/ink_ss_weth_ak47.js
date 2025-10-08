const { chainIdByName, toBytes, isHardhat, tryGetContract, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSInkWethAK47';
const bundlerId = 'SS-INK-WETH-AK47';
const priceSlippage = 300n; // 3%

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  // Only run on INK Chain
  if (chainId !== 57073 && chainId !== 763373) { return; }

  const routers = globals.router[chainId];
  const tokenAddress = globals.tokenAddress[chainId];
  const web3packs = await ethers.getContract('Web3PacksV2');
  const web3packsState = await ethers.getContract('Web3PacksState');

  const constructorArgs = [{
    weth: tokenAddress.weth,
    token0: tokenAddress.weth,
    token1: tokenAddress.ak47,
    manager: web3packs.address,
    swapRouter: routers.inky,
    liquidityRouter: routers.inky,
    poolId: toBytes(''),
    bundlerId: toBytes(bundlerId),
    slippage: priceSlippage,
    tickLower: 100,
    tickUpper: 100,
  }];

  let bundler = await tryGetContract(bundlerContractName);
  if (!bundler.address) {
    //
    // Deploy Contracts
    //
    log(`\nDeploying ${bundlerContractName} Bundler...`);

    await deploy(bundlerContractName, {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    bundler = await ethers.getContract(bundlerContractName);
    if (!isHardhat(network)) {
      await verifyContract(bundlerContractName, bundler, constructorArgs);
    }
  }

  log(`  Updating Manager (Web3Packs) in Bundler: ${bundlerId}`);
  await bundler.setManager(web3packs.address).then(tx => tx.wait());

  log(`  Registering Bundler in Web3Packs: ${bundlerId} = ${bundler.address}`);
  await web3packsState.registerBundlerId(toBytes(bundlerId), bundler.address).then(tx => tx.wait());
};

module.exports.tags = [bundlerId];
