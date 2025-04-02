const { chainNameById, chainIdByName, isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');
const _ = require('lodash');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer, treasury, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);

  const contracts = globals.contracts[chainId];
  const tokenAddress = globals.tokenAddress[chainId];

  const useExistingWeb3PacksContract = isHardhat(network) ? '' : '';
  const useExistingWeb3PacksStateContract = isHardhat(network) ? '' : '';

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Charged Particles - Web3 Packs V2 - Contract Deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  log('  Using Accounts:');
  log('  - Deployer: ', deployer);
  log('  - Treaury:  ', treasury);
  log('  - User1:    ', user1);
  log(' ');

  // Deploy & Verify Web3PacksV2
  if (useExistingWeb3PacksContract.length === 0) {
    log('  Deploying Web3PacksV2...');
    const constructorArgs = [
      tokenAddress.weth,
      contracts.protonC,
      contracts.chargedParticles,
      contracts.chargedState,
    ];
    await deploy('Web3PacksV2', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    if (!isHardhat(network)) {
      await verifyContract('Web3PacksV2', await ethers.getContract('Web3PacksV2'), constructorArgs);
    }
  }

  // Get Deployed Web3PacksV2
  let web3packs;
  if (useExistingWeb3PacksContract.length === 0) {
    web3packs = await ethers.getContract('Web3PacksV2');
  } else {
    web3packs = await ethers.getContractAt('Web3PacksV2', useExistingWeb3PacksContract);
  }

  // Deploy & Verify Web3PacksState
  if (useExistingWeb3PacksStateContract.length === 0) {
    log('  Deploying Web3PacksState...');
    const constructorArgs = [
      web3packs.address,
    ];
    await deploy('Web3PacksState', {
      from: deployer,
      args: constructorArgs,
      log: true,
    });

    if (!isHardhat(network)) {
      await verifyContract('Web3PacksState', await ethers.getContract('Web3PacksState'), constructorArgs);
    }
  }

  // Get Deployed Web3PacksState
  let web3packsState;
  if (useExistingWeb3PacksContract.length === 0) {
    web3packsState = await ethers.getContract('Web3PacksState');
  } else {
    web3packsState = await ethers.getContractAt('Web3PacksState', useExistingWeb3PacksStateContract);
  }


  // Configure Newly Deployed Web3PacksV2
  if (useExistingWeb3PacksContract.length === 0) {
    log(`  Setting Protocol Fee in Web3Packs: ${globals.protocolFee}`);
    await web3packs.setProtocolFee(globals.protocolFee).then(tx => tx.wait());

    log(`  Setting Web3PacksState in Web3Packs: ${globals.protocolFee}`);
    await web3packs.setWeb3PacksState(web3packsState.address).then(tx => tx.wait());

    log(`  Setting Protocol Treasury in Web3Packs: ${treasury}`);
    await web3packs.setTreasury(treasury).then(tx => tx.wait());
  }
};

// module.exports.dependencies = ['ERC20Mintable', 'ERC721Mintable'];
module.exports.tags = ['web3packs']
