const { log } = require('../js-helpers/utils');

const _MODE_BUNDLES = [
  'SS-WETH-BMX',
  'SS-WETH-ICL',
  'SS-WETH-IONX',
  'SS-WETH-KIM',
  'SS-WETH-MODE',
  'SS-WETH-SMD',
  'SS-WETH-WMLT',
  'SS-WETH-PACKY',
  'SS-WETH-CARTEL',
  'SS-WETH-GAMBL'
];

const _BSC_BUNDLES = [
  'SS-BSC-WETH-BUSD',
];

module.exports = async (hre) => {
    log('\n---\nSingle-Sided Bundlers Deployed!');
};

module.exports.dependencies = _MODE_BUNDLES;
module.exports.tags = ['deploySS']
