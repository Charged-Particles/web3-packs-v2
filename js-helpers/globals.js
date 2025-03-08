const { utils } = require('ethers');

const globals = {
  contracts: {
    34443: {
      chargedParticles: '0x0288280Df6221E7e9f23c1BB398c820ae0Aa6c10',
      chargedState: '0x2691B4f4251408bA4b8bf9530B6961b9D0C1231F',
      protonC: '0x76a5df1c6F53A4B80c8c8177edf52FBbC368E825',
    },
  },

  tokenAddress: {
    34443: {
      weth: '0x4200000000000000000000000000000000000006',
      usdc: '0xd988097fb8612cc24eeC14542bC03424c656005f',
      usdt: '0xf0F161fDA2712DB8b566946122a5af183995e2eD',
      uni: '0xb33EaAd8d922B1083446DC23f610c2567fB5180f',
      dai: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
      mode: '0xDfc7C877a950e49D2610114102175A06C2e3167a',
      ion: '0x18470019bF0E94611f15852F7e93cf5D65BC34CA',
      icl: '0x95177295A394f2b9B04545FFf58f4aF0673E839d',
      ezeth: '0x2416092f143378750bb29b79eD961ab195CcEea5',
      ionx: '0x77E7bcfeE826b12cD498Faa9831d7055b7478272',
      kim: '0x6863fb62Ed27A9DdF458105B507C15b5d741d62e',
      djump: '0xb9dF4BD9d3103cF1FB184BF5e6b54Cf55de81747',
      wmlt: '0x8b2EeA0999876AAB1E7955fe01A5D261b570452C',
      bmx: '0x66eEd5FF1701E6ed8470DC391F05e27B1d0657eb',
      pmode: '0x7E0ddf49F70a1916849523d3F43DD5AFf27C6587',
      mochad: '0xcDa802a5BFFaa02b842651266969A5Bba0c66D3e',
      peas: '0x02f92800F57BCD74066F5709F1Daa1A4302Df875',
      ppeas: '0x064EFc5cb0B7BC52Ac9e717eA5F3F35f3534f855',
      susde: '0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2',
      iusd: '0xA70266C8F8Cf33647dcFEE763961aFf418D9E1E4',
      wbtc: '0xcdd475325d6f564d27247d1dddbb0dac6fa0a5cf',
      stone: '0x80137510979822322193FC997d400D5A6C747bf7',
      smd: '0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB',
      cartel: '0x98E0AD23382184338dDcEC0E13685358EF845f30',
    },
  },

  router: {
    34443: {
      velodrome: '0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45',
      kim: '0xAc48FcF1049668B285f3dC72483DF5Ae2162f7e8',
      kimNft: '0x2e8614625226D26180aDf6530C3b1677d3D7cf10',
      balancer: '0xBA12222222228d8Ba445958a75a0704d566BF2C8',
      swapMode: '0xc1e624C810D297FD70eF53B0E08F44FABE468591',
    },
  },

  poolId: {
    34443: {
      balancerMode: '0x7c86a44778c52a0aad17860924b53bf3f35dc932000200000000000000000007',
      balancerEzEth: '0x16453789fed619c7fa18c068dec1cb2766ba2e3e000000000000000000000006',
    },
  },

  // Standard Parameters
  deadline: Math.floor(Date.now() / 1000) + (60 * 10),
  protocolFee: utils.parseUnits('0.0001', 18),

  erc20Abi : [
    'function transfer(address to, uint amount)',
    'function balanceOf(address account) public view returns (uint256)',
    'function approve(address spender, uint256 amount) external returns (bool)'
  ],
  wethAbi : [
    'function deposit() public',
    'function withdraw(uint wad) public',
  ],

  // IPFS
  ipfsMetadata: 'Qmao3Rmq9m38JVV8kuQjnL3hF84cneyt5VQETirTH1VUST',


  //
  //  OLD:
  //

  treasury: '',

  // Charged Particles
  chargedStateContractAddress: '0x2691B4f4251408bA4b8bf9530B6961b9D0C1231F',

  // Proton NFT Address
  protonPolygon: '0x1CeFb0E1EC36c7971bed1D64291fc16a145F35DC',
  protonMode: '0x76a5df1c6F53A4B80c8c8177edf52FBbC368E825',

  // Token Addresses
  USDcContractAddress: '0xd988097fb8612cc24eeC14542bC03424c656005f',
  USDtContractAddress:  '0xf0F161fDA2712DB8b566946122a5af183995e2eD',
  UniContractAddress: '0xb33EaAd8d922B1083446DC23f610c2567fB5180f',
  DAIContractAddress: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
  wrapMaticContractAddress: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
  wrapETHAddress: '0x4200000000000000000000000000000000000006',
  modeTokenAddress: '0xDfc7C877a950e49D2610114102175A06C2e3167a',
  ionTokenAddress: '0x18470019bF0E94611f15852F7e93cf5D65BC34CA',
  iclTokenAddress: '0x95177295A394f2b9B04545FFf58f4aF0673E839d',
  ezEthTokenAddress: '0x2416092f143378750bb29b79eD961ab195CcEea5',
  ionxTokenAddress: '0x77E7bcfeE826b12cD498Faa9831d7055b7478272',
  wethModeLpTokenAddress: '0x7c86a44778c52a0aad17860924b53bf3f35dc932',

  // IPFS
  ipfsMetadata: 'Qmao3Rmq9m38JVV8kuQjnL3hF84cneyt5VQETirTH1VUST',

  // Velodrome Router
  velodromeRouter: '0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45',
  velodromeRouterAbi: [
    'function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, (address,address,bool)[] calldata routes, address to, uint256 deadline) external returns (uint256[] memory amounts)',
    'function swapExactETHForTokens(uint256 amountOutMin, (address,address,bool)[] routes, address to, uint256 deadline) payable returns (uint256[] memory amounts)',
    'function addLiquidity(address tokenA, address tokenB, bool stable, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) public returns (uint256 amountA, uint256 amountB, uint256 liquidity)',
    'function removeLiquidity(address tokenA, address tokenB, bool stable, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) public returns (uint256 amountA, uint256 amountB)',
  ],

  // Kim Router
  kimRouterMode: '0xAc48FcF1049668B285f3dC72483DF5Ae2162f7e8',
  KimNonfungibleTokenPosition: '0x2e8614625226D26180aDf6530C3b1677d3D7cf10',

  // Balancer (Router is Vault)
  balancerVault: '0xBA12222222228d8Ba445958a75a0704d566BF2C8',
  balancerModePoolId: '0x7c86a44778c52a0aad17860924b53bf3f35dc932000200000000000000000007',
  balancerModeLpToken: '0x7c86a44778c52a0aad17860924b53bf3f35dc932',
  balancerEzEthPoolId: '0x16453789fed619c7fa18c068dec1cb2766ba2e3e000000000000000000000006',
  balancerEzEthLpToken: '0x16453789fed619c7fa18c068dec1cb2766ba2e3e',

  // Standard Parameters
  deadline: Math.floor(Date.now() / 1000) + (60 * 10),
  protocolFee: utils.parseUnits('0.0001', 18),

  // Random Addresses
  testAddress: '0x277BFc4a8dc79a9F194AD4a83468484046FAFD3A',
  USDcWhale: '0xfa0b641678f5115ad8a8de5752016bd1359681b9',
};

module.exports = globals;