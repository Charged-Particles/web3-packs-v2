const { chainNameById, chainIdByName, isHardhat, log } = require('../js-helpers/utils');
const { verifyContract } = require('../js-helpers/verifyContract');
const globals = require('../js-helpers/globals');
const _ = require('lodash');

const _PRIMARY_VAULT_CHAIN_ID = 57073;

module.exports = async (hre) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);
  const asPrimaryVault = true; // isHardhat(network) || _PRIMARY_VAULT_CHAIN_ID === chainId;

  const contracts = globals.contracts[chainId];
  const useExistingVaultContract = isHardhat(network) ? '' : '0x502B98842a9d71cd24C32bd51810A64a1C9790ba';
  const useExistingVaultProxyContract = isHardhat(network) ? '' : '';

  async function _deployPrimaryVault(web3packsAddress) {
    // Deploy & Verify Vault
    if (useExistingVaultContract.length === 0) {
      log('  Deploying Web3PacksVault...');
      const constructorArgs = [
        web3packsAddress,
        ethers.constants.AddressZero, // Proxy address
      ];
      await deploy('Web3PacksVault', {
        from: deployer,
        args: constructorArgs,
        log: true,
      });

      if (!isHardhat(network)) {
        await verifyContract('Web3PacksVault', await ethers.getContract('Web3PacksVault'), constructorArgs);
      }
    }

    // Get Deployed Web3PacksVault
    let web3packsVault;
    if (useExistingVaultContract.length === 0) {
      web3packsVault = await ethers.getContract('Web3PacksVault');
    } else {
      web3packsVault = await ethers.getContractAt('Web3PacksVault', useExistingVaultContract);
    }
    return web3packsVault;
  }

  async function _deployProxyVault(web3packsAddress) {
    // Deploy & Verify Vault
    if (useExistingVaultProxyContract.length === 0) {
      log('  Deploying Web3PacksVaultProxy...');
      const constructorArgs = [
        web3packsAddress,
      ];
      await deploy('Web3PacksVaultProxy', {
        from: deployer,
        args: constructorArgs,
        log: true,
      });

      if (!isHardhat(network)) {
        await verifyContract('Web3PacksVaultProxy', await ethers.getContract('Web3PacksVaultProxy'), constructorArgs);
      }
    }

    // Get Deployed Web3PacksVaultProxy
    let web3packsVaultProxy;
    if (useExistingVaultProxyContract.length === 0) {
      web3packsVaultProxy = await ethers.getContract('Web3PacksVaultProxy');
    } else {
      web3packsVaultProxy = await ethers.getContractAt('Web3PacksVaultProxy', useExistingVaultProxyContract);
    }
    return web3packsVaultProxy;
  }


  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Charged Particles - Web3 Packs V2 - Vault Deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  log('  Using Accounts:');
  log('  - Deployer: ', deployer);
  log(' ');

  if (!asPrimaryVault) {
    log('  Deploying Vault as Proxy..\n');
    if (useExistingVaultContract.length === 0) {
      log('  Missing Primary Vault Contract Address!\n');
      return;
    }
  }

  // Get Deployed Web3PacksV2
  const web3packs = await ethers.getContract('Web3PacksV2');

  // Deploy & Verify Vault
  let vault = { address: '' };
  if (asPrimaryVault) {
    // vault = await _deployPrimaryVault(web3packs.address);
    vault.address = useExistingVaultContract;

    // Configure Newly Deployed Web3PacksVault
    log(`  Setting Vault in Web3Packs: ${vault.address}`);
    await web3packs.setWeb3PacksVault(vault.address).then(tx => tx.wait());

    log(`  Setting Web3Packs in Vault: ${web3packs.address}`);
    const vaultContract = await ethers.getContractAt('Web3PacksVault', vault.address);
    await vaultContract.setWeb3Packs(web3packs.address).then(tx => tx.wait());
  } else {
    vault = await _deployProxyVault(web3packs.address);

    const rewardsToken = '';
    const rewardsQuoteToken = '';
    const channelId = 1;
    const destinationPath = 1;

    // Configure Newly Deployed Web3PacksVaultProxy
    log(`  Setting Vault in Web3Packs: ${vault.address}`);
    await web3packs.setWeb3PacksVault(vault.address).then(tx => tx.wait());

    log(`  Setting Primary Vault in VaultProxy: ${useExistingVaultContract}`);
    await vault.setWeb3PacksVault(useExistingVaultContract).then(tx => tx.wait());

    log(`  Setting Rewards Token in VaultProxy: ${rewardsToken}`);
    await vault.setRewardsToken(rewardsToken).then(tx => tx.wait());

    log(`  Setting Rewards Quote Token in VaultProxy: ${rewardsQuoteToken}`);
    await vault.setRewardsQuoteToken(rewardsQuoteToken).then(tx => tx.wait());

    log(`  Setting Channel ID in VaultProxy: ${channelId}`);
    await vault.setChannelId(channelId).then(tx => tx.wait());

    log(`  Setting Destination Path in VaultProxy: ${destinationPath}`);
    await vault.setDestinationPath(destinationPath).then(tx => tx.wait());
  }
};

module.exports.tags = ['Vaults']
