const { ethers } = require('hardhat');
const fs = require('fs');
const path = require('path');
const _ = require('lodash');

const toWei = ethers.utils.parseEther;
const toEth = ethers.utils.formatEther;
const toStr = (val) => ethers.utils.toUtf8String(val).replace(/\0/g, '');
const toBytes = ethers.utils.formatBytes32String;

const toBN = function(number, defaultValue = null) {
  if (number === null) {
    if (defaultValue === null) {
      return null;
    }
    number = defaultValue;
  }
  return ethers.BigNumber.from(number);
}

const log = (...args) => {
  console.log(...args);
};

const isHardhat = (network) => {
  const isForked = network?.config?.forking?.enabled ?? false;
  return isForked || network?.name === 'hardhat';
};

const chainIdByName = (chainName) => {
  switch (_.toLower(chainName)) {
    case 'homestead': return 1;
    case 'mainnet': return 1;
    case 'ropsten': return 3;
    case 'rinkeby': return 4;
    case 'goerli': return 5;
    case 'kovan': return 42;
    case 'polygon': return 137;
    case 'mumbai': return 80001;
    case 'bsctestnet': return 97;
    case 'bsc': return 56;
    case 'hardhat': return 34443;
    case 'coverage': return 31337;
    case 'mode': return 34443;
    default: return 0;
  }
};

const chainNameById = (chainId) => {
  switch (parseInt(chainId, 10)) {
    case 1: return 'Mainnet';
    case 3: return 'Ropsten';
    case 4: return 'Rinkeby';
    case 5: return 'Goerli';
    case 42: return 'Kovan';
    case 137: return 'Polygon';
    case 80001: return 'Mumbai';
    case 56: return 'BSC';
    case 97: return 'BSC Testnet';
    case 31337: return 'Hardhat';
    default: return 'Unknown';
  }
};

const chainTypeById = (chainId) => {
  switch (parseInt(chainId, 10)) {
    case 1:
    case 56:
    case 137:
      return {isProd: true, isTestnet: false, isHardhat: false};
    case 3:
    case 4:
    case 42:
    case 97:
    case 80001:
      return {isProd: false, isTestnet: true, isHardhat: false};
    case 31337:
    default:
      return {isProd: false, isTestnet: false, isHardhat: true};
  }
};

const findNearestValidTick = (tickSpacing, nearestToMin) => {
  const MIN_TICK = -887272;
  const MAX_TICK = 887272;

  if (nearestToMin) {
    // Adjust to the nearest valid tick above MIN_TICK
    return Math.ceil(MIN_TICK / tickSpacing) * tickSpacing;
  } else {
    // Adjust to the nearest valid tick below MAX_TICK
    return Math.floor(MAX_TICK / tickSpacing) * tickSpacing;
  }
};

const ensureDirectoryExistence = (filePath) => {
  var dirname = path.dirname(filePath);
  if (fs.existsSync(dirname)) {
    return true;
  }
  ensureDirectoryExistence(dirname);
  fs.mkdirSync(dirname);
};

module.exports = {
  toWei,
  toEth,
  toBN,
  toStr,
  toBytes,
  log,
  isHardhat,
  chainTypeById,
  chainNameById,
  chainIdByName,
  findNearestValidTick,
  ensureDirectoryExistence,
}