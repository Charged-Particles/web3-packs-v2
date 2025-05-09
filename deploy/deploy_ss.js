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

const _INK_BUNDLES = [
  'SS-INK-WETH-IETH',
];

const _BERA_BUNDLES = [
  'SS-BERA-WETH-USDC',
];

module.exports = async (hre) => {
    log('\n---\nSingle-Sided Bundlers Deployed!');
};

module.exports.dependencies = _INK_BUNDLES;
module.exports.tags = ['deploySS']
