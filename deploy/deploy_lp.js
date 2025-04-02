const { log } = require('../js-helpers/utils');

const _MODE_BUNDLES = [
  'LP-IUSD-USDC',
  'LP-WETH-IONX',
  'LP-WETH-KIM',
  'LP-WETH-MODE',
  'LP-WETH-MODE-8020',
  'LP-WETH-STONE',
  'LP-WETH-USDC',
  'LP-WETH-WBTC'
];

const _BSC_BUNDLES = [
];

module.exports = async (hre) => {
    log('\n---\nLiquidity-Position Bundlers Deployed!');
};

module.exports.dependencies = _MODE_BUNDLES;
module.exports.tags = ['deployLP']
