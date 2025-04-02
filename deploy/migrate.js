const { chainNameById, chainIdByName, toBytes, log } = require('../js-helpers/utils');
const globals = require('../js-helpers/globals');
const _ = require('lodash');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre;
  const { deployer, treasury, user1 } = await getNamedAccounts();
  const network = await hre.network;
  const chainId = chainIdByName(network.name);
  const contracts = globals.contracts[chainId];

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('Charged Particles - Web3 Packs V2 - Contract Migration');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log(`  Using Network: ${chainNameById(chainId)} (${network.name}:${chainId})`);
  log('  Using Accounts:');
  log('  - Deployer: ', deployer);
  log('  - Treaury:  ', treasury);
  log('  - User1:    ', user1);
  log(' ');


  const ECO = _.map([ 'SS-WETH-MODE', 'SS-WETH-WMLT', 'SS-WETH-IONX', 'SS-WETH-KIM', 'SS-WETH-ICL', 'SS-WETH-SMD', 'SS-WETH-BMX' ], bundleId => toBytes(bundleId));
  const DEFI = _.map([ 'LP-WETH-KIM', 'LP-WETH-MODE', 'LP-WETH-IONX', 'LP-WETH-WBTC', 'LP-WETH-USDC', 'LP-WETH-STONE' ], bundleId => toBytes(bundleId));
  const DEFI_OLD = _.map([ 'LP-WETH-KIM', 'LP-WETH-MODE', 'LP-WETH-IONX', 'LP-WETH-WBTC', 'LP-WETH-USDC', 'LP-WETH-STONE', 'LP-IUSD-USDC' ], bundleId => toBytes(bundleId));
  const GOV = _.map([ 'SS-WETH-IONX', 'SS-WETH-MODE', 'LP-WETH-MODE-8020' ], bundleId => toBytes(bundleId));
  const AI = _.map([ 'SS-WETH-PACKY', 'SS-WETH-CARTEL', 'SS-WETH-GAMBL' ], bundleId => toBytes(bundleId));

  const _getPackBalance = async (tokenId) => {
    try {
      return await web3packs.callStatic.getPackBalances(contracts.protonC, tokenId);
    } catch (err) {
      return [];
    }
  };

  // Get Deployed Web3PacksState
  const web3packs = await ethers.getContractAt('Web3PacksV2', '0xEEC393142db33eb94C18f3d5514888Ad5e7BECc2');
  const web3packsState = await ethers.getContractAt('Web3PacksState', '0xD0CDC6aF34B01dB1f84b4ECC1d029d6a11eaBa3a');

  if (web3packsState.address.length > 0) {
    for (let i = 2898; i < 2899; i++) {
      const tokenId = i;
      const tokenAmounts = await _getPackBalance(tokenId);
      const nftCount = _.reduce(tokenAmounts, (sum, obj) => sum + (obj.nftTokenId > 0 ? 1 : 0), 0);

      let packType = '';
      let bundleIds = [];
      if (tokenAmounts.length === 0) {
        // Unbundled, no need to migrate
        log(`  Skipping Unbundled Pack with TokenId: ${tokenId}...`);
        continue;
      }
      if (tokenAmounts.length === 3) {
        const balancerLpToken = _.find(tokenAmounts, { tokenAddress: '0x7c86a44778c52a0aad17860924b53bf3f35dc932' });
        if (balancerLpToken) {
          packType = 'GOVERNANCE';
          bundleIds = GOV;
        } else {
          packType = 'AI';
          bundleIds = AI;
        }
      }
      if (tokenAmounts.length === 6) {
        packType = 'DEFI';
        bundleIds = DEFI;
      }
      if (tokenAmounts.length === 7) {
        if (nftCount === 0) {
          packType = 'ECOSYSTEM';
          bundleIds = ECO;
        } else {
          packType = 'DEFI';
          bundleIds = DEFI_OLD;
        }
      }

      log(`  Migrating ${packType} Pack with TokenId: ${tokenId}...`);
      await web3packsState.migratePackData(web3packs.address, tokenId, bundleIds)
    }
  } else {
    log('  Missing Web3PacksState Contract!');
  }
};

module.exports.tags = ['migrate']
