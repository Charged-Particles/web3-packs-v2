const { log } = require('../js-helpers/utils');

module.exports = async (hre) => {
    log('Liquidity-Position Bundlers Deployed!');
};

module.exports.dependencies = ['LP-IUSD-USDC', 'LP-WETH-IONX', 'LP-WETH-KIM', 'LP-WETH-MODE', 'LP-WETH-MODE-8020', 'LP-WETH-STONE', 'LP-WETH-USDC', 'LP-WETH-WBTC'];
module.exports.tags = ['deployLP']
