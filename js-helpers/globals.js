const { utils } = require('ethers');

const globals = {
  contracts: {
    919: {
      chargedParticles: '0xdD5B990d752d53A93CcaE0aA3aDBbe0940d93d46',
      chargedState: '0x7a6561daD7EfB841D08B6891AFbFE7e98D8052D6',
      protonC: '0x009aE96a0277eE2590b6a382B9f94E5bdD8063Cc',
    },
    34443: {
      chargedParticles: '0x0288280Df6221E7e9f23c1BB398c820ae0Aa6c10',
      chargedState: '0x2691B4f4251408bA4b8bf9530B6961b9D0C1231F',
      protonC: '0x76a5df1c6F53A4B80c8c8177edf52FBbC368E825',
    },
    97: {
      chargedParticles: '0x4a7b80e418454a21A49885b009d51f0d0A6Ed77A',
      chargedState: '0xc42De19eB6eB8fa3eCCcA9Ad0F2E4795c468310f',
      protonC: '0xE0dbEc1fE9c4148c85815abE93D496F5f909EB65',
    },
  },

  tokenAddress: {
    919: {
      weth: '0xeb72756ee12309Eae82a0deb9787e69f5b62949c',
      mode: '0x4FFa6cDEB4deF980b75e3F4764797A2CAd1fAEF3',
    },
    34443: {
      weth: '0x4200000000000000000000000000000000000006',
      usdc: '0xd988097fb8612cc24eeC14542bC03424c656005f',
      usdt: '0xf0F161fDA2712DB8b566946122a5af183995e2eD',
      mode: '0xDfc7C877a950e49D2610114102175A06C2e3167a',
      ion: '0x18470019bF0E94611f15852F7e93cf5D65BC34CA',
      icl: '0x95177295A394f2b9B04545FFf58f4aF0673E839d',
      ezeth: '0x2416092f143378750bb29b79eD961ab195CcEea5',
      ionx: '0x77E7bcfeE826b12cD498Faa9831d7055b7478272',
      kim: '0x6863fb62Ed27A9DdF458105B507C15b5d741d62e',
      djump: '0xb9dF4BD9d3103cF1FB184BF5e6b54Cf55de81747',
      wmlt: '0x8b2EeA0999876AAB1E7955fe01A5D261b570452C',
      bmx: '0x66eEd5FF1701E6ed8470DC391F05e27B1d0657eb',
      mochad: '0xcDa802a5BFFaa02b842651266969A5Bba0c66D3e',
      peas: '0x02f92800F57BCD74066F5709F1Daa1A4302Df875',
      ppeas: '0x064EFc5cb0B7BC52Ac9e717eA5F3F35f3534f855',
      susde: '0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2',
      iusd: '0xA70266C8F8Cf33647dcFEE763961aFf418D9E1E4',
      wbtc: '0xcdd475325d6f564d27247d1dddbb0dac6fa0a5cf',
      stone: '0x80137510979822322193FC997d400D5A6C747bf7',
      smd: '0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB',
      packy: '0x99abb182e574dad9e238a529126051f01db380d5',
      cartel: '0x98E0AD23382184338dDcEC0E13685358EF845f30',
      gambl: '0x6bb4a37643e7613e812a8d1af5e675cc735ea1e2',
    },
    97: {
      weth: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd', // WBNB on BSC
      busd: '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee',
      usdt: '0x64544969ed7EBf5f083679233325356EbE738930',
      tusd: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
      cake: '0xFa60D973F7642B748046464e165A65B7323b0DEE',
    },
  },

  router: {
    919: {
      velodrome: '',
      velodromeV2: '',
      kim: '',
      kimNft: '',
      balancer: '',
      swapMode: '',
    },
    34443: {
      velodrome: '0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45',
      velodromeV2: '0x652e53C6a4FE39B6B30426d9c96376a105C89A95',
      kim: '0xAc48FcF1049668B285f3dC72483DF5Ae2162f7e8',
      kimNft: '0x2e8614625226D26180aDf6530C3b1677d3D7cf10',
      balancer: '0xBA12222222228d8Ba445958a75a0704d566BF2C8',
      swapMode: '0xc1e624C810D297FD70eF53B0E08F44FABE468591',
    },
    97: {
      pancakeSwapUni: '0x9A082015c919AD0E47861e5Db9A1c7070E81A2C7',
      pancakeSwapV3: '0x1b81D678ffb9C0263b24A97847620C99d213eB14',
      pancakeSwapV3Nft: '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364',
      pancakeSwapV2: '0xD99D1c33F9fC3444f8101754aBC46c52416550D1',
    },
  },

  poolId: {
    919: {
      balancerMode: '',
      balancerEzEth: '',
    },
    34443: {
      balancerMode: '0x7c86a44778c52a0aad17860924b53bf3f35dc932000200000000000000000007',
      balancerEzEth: '0x16453789fed619c7fa18c068dec1cb2766ba2e3e000000000000000000000006',
    },
  },

  // Standard Parameters
  deadline: Math.floor(Date.now() / 1000) + (60 * 10),
  protocolFee: utils.parseUnits('0.0001', 18),
  ipfsMetadata: 'Qmao3Rmq9m38JVV8kuQjnL3hF84cneyt5VQETirTH1VUST',

  erc20Abi : [
    'function transfer(address to, uint amount)',
    'function balanceOf(address account) public view returns (uint256)',
    'function approve(address spender, uint256 amount) external returns (bool)'
  ],
  wethAbi : [
    'function deposit() public',
    'function withdraw(uint wad) public',
  ],
};

module.exports = globals;