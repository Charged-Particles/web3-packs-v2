const { log } = require('../js-helpers/utils');

module.exports = async (hre) => {
    log('Single-Sided Bundlers Deployed!');
};

module.exports.dependencies = ['SS-WETH-BMX', 'SS-WETH-ICL', 'SS-WETH-IONX', 'SS-WETH-KIM', 'SS-WETH-MODE', 'SS-WETH-SMD', 'SS-WETH-WMLT'];
module.exports.tags = ['deploySS']
