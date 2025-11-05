const { utils, constants } = require('ethers');

// Chains:
// 1 - Ethereum Mainnet
// 11155111 - Ethereum Sepolia Testnet

// 919 - MODE Mainnet
// 34443 - MODE Testnet

// 56 - BSC Mainnet
// 97 - BSC Testnet

// 137 - Polygon Mainnet
// 80001 - Polygon Mumbai Testnet
// 80002 - Polygon Amoy Testnet

// 8453 - Base Mainnet
// 84532 - Base Testnet

// 80094 - Berachain Mainnet
// 80069 - Berachain Bepolia Testnet

// 57073 - INK Mainnet
// 763373 - INK Testnet

const globals = {
  contracts: {
    // MODE
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
    // INK
    763373: {
      chargedParticles: '0x2Ff4613a12570a77D88376A3e5d0FF68953b3fd8',
      chargedState: '0x10a4b06BA9aC1Bf6e44F17EAf5c0D05c98F82704',
      protonC: '0xd7240874cf781531520ce59373624B30d788d27f',
    },
    57073: {
      chargedParticles: '0x54b32b288d7904D5d98Be1910975a80e45DA5e8d',
      chargedState: '0xB29256073C63960daAa398f1227D0adBC574341C',
      protonC: '0xe2a9b15E283456894246499Fb912CCe717f83319',
    },
    // BSC
    97: {
      chargedParticles: '0x4a7b80e418454a21A49885b009d51f0d0A6Ed77A',
      chargedState: '0xc42De19eB6eB8fa3eCCcA9Ad0F2E4795c468310f',
      protonC: '0xE0dbEc1fE9c4148c85815abE93D496F5f909EB65',
    },
    // Polygon
    137: {
      chargedParticles: '0x0288280Df6221E7e9f23c1BB398c820ae0Aa6c10',
      chargedState: '0x9c00b8CF03f58c0420CDb6DE72E27Bf11964025b',
      protonC: '0x59dde2EBe605cD75365F387FFFE82E5203b8E4cd',
    },
    // somniaTestnet
    50312: {
      chargedParticles: '0xd8bFF003AcfF6067B5F6AB1EC966eD650C6f0740',
      chargedState: '0x54F9A3f294dBd6f5a100084647bd0E6EcD4b653e',
      protonC: '0x9E61185CDDA5De038Cebd4C04E82b90952a186bE',
    }
  },

  tokenAddress: {
    // MODE
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
    // INK
    57073: {
      weth: '0x4200000000000000000000000000000000000006',
      ieth: '0x11476323D8DFCBAFac942588E2f38823d2Dd308e',
      usdt0: '0x0200C29006150606B650577BBE7B6248F58470c1',
      kbtc: '0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98',
      usdce: '0xF1815bd50389c46847f0Bda824eC8da914045D14',
    },
    763373: {
      weth: '0x4200000000000000000000000000000000000006',
    },
    // BSC
    97: {
      weth: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd', // WBNB on BSC
      busd: '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee',
      usdt: '0x64544969ed7EBf5f083679233325356EbE738930',
      tusd: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
      cake: '0xFa60D973F7642B748046464e165A65B7323b0DEE',
    },
    // Polygon
    137: {
      weth: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
      pack: '0x4fb9b94bd8bbbd684a7d5a5544bc7a07188e5617',
      h2dao: '0x6fc91fbe42f72941486c98d11724b14fb8d18b36',
      tdm: '0x878b6bf76f7ba67d0c4da616eac1933f9b133c1c',
      lock: '0x69ce536f95a84e1ef51ed0132c514c7ce012e49b',
    },
    // somniaTestnet
    50312: {
      wsomi: '0x046EDe9564A72571df6F5e44d0405360c0f4dCab',
      weth: '0xdd8f41bf80d0E47132423339ca06bC6413da96b5',
    }
  },

  router: {
    // MODE
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
    // INK
    763373: {
      velodrome: '',
      velodromeV2: '',
    },
    57073: {
      velodrome: '0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45',
      velodromeV2: '0x652e53C6a4FE39B6B30426d9c96376a105C89A95',
    },
    // BSC
    97: {
      pancakeSwapUni: '0x9A082015c919AD0E47861e5Db9A1c7070E81A2C7',
      pancakeSwapV3: '0x1b81D678ffb9C0263b24A97847620C99d213eB14',
      pancakeSwapV3Nft: '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364',
      pancakeSwapV2: '0xD99D1c33F9fC3444f8101754aBC46c52416550D1',
    },
    // Polygon
    137: {
      quickswapAlgebra: '0xf5b509bB0909a69B1c207E495f687a596C168E12', // Swap router
      quickswapAlgebraLP: '0x8eF88E4c7CfbbaC1C163f7eddd4B578792201de6', // Non fungible position manager
    },
    // somniaTestnet
    50312: {
      quickswapAlgebra: '', // Swap router
      quickswapAlgebraLP: '', // Non fungible position manager
    }
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