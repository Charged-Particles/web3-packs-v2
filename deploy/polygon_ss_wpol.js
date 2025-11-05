const { chainIdByName, toBytes, isHardhat, findNearestValidTick, tryGetContract, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');

const bundlerContractName = 'SSPolyWpol';
const bundlerId = 'SS-POLY-WPOL';
const priceSlippage = 300n; // 3%

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  // Only run on Polygon Chain
  if (chainId !== 137 && chainId !== 80002) { return; }

  const useExistingWeb3PacksContract = isHardhat(network) ? '' : '0xbFf28A2a8C5f45D16f7E3629967563F33b3bdC78';
  const useExistingWeb3PacksStateContract = isHardhat(network) ? '' : '0x42229C922b6Ddc1609222601CC7e7C53B0cA85E2';

  const routers = globals.router[chainId];
  const tokenAddress = globals.tokenAddress[chainId];

  // Get Deployed Web3PacksV2
  let web3packs;
  if (useExistingWeb3PacksContract.length === 0) {
    web3packs = await ethers.getContract('Web3PacksV2');
  } else {
    web3packs = await ethers.getContractAt('Web3PacksV2', useExistingWeb3PacksContract);
  }

  // Get Deployed Web3PacksState
  let web3packsState;
  if (useExistingWeb3PacksStateContract.length === 0) {
    web3packsState = await ethers.getContract('Web3PacksState');
  } else {
    web3packsState = await ethers.getContractAt('Web3PacksState', useExistingWeb3PacksStateContract);
  }

  log(`  Web3PacksV2: ${web3packs.address}`);
  log(`  Web3PacksState: ${web3packsState.address}`);
  log(`  Bundler: ${bundlerContractName}`);

  const constructorArgs = [{
    weth: tokenAddress.wpol,
    token0: tokenAddress.wpol,
    token1: tokenAddress.wpol,
    manager: web3packs.address,
    swapRouter: routers.quickswapAlgebra,
    liquidityRouter: routers.quickswapAlgebraLP,
    poolId: toBytes(''),
    bundlerId: toBytes(bundlerId),
    slippage: priceSlippage,
    tickLower: BigInt(findNearestValidTick(60, true)),
    tickUpper: BigInt(findNearestValidTick(60, false)),
  }];

  let bundler = await tryGetContract(bundlerContractName);
  log(`  Bundler Address: ${bundler.address}`);
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
