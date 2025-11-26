// npx hardhat run scripts/mint-lpwsomi-usdc.js --network somnia
const { ethers } = require("hardhat");
const fs = require("fs");

// ============================================
// SOMNIA MAINNET ADDRESSES
// ============================================

// Web3Packs Contracts (newly deployed)
const WEB3PACKS_V2_ADDRESS = "0x759E687B319ed018bfA2961a6fD81D4Cf7ce1998";
const WEB3PACKS_STATE_ADDRESS = "0xA81Af7f20eC2ac6DA01F73631f61f254142Bc19E";

// Bundler (LP-WSOMI-USDC)
const BUNDLER_ADDRESS = "0x127b9Dd748109EB46e86725f3785aF7489D88a0e";
const BUNDLER_ID = "0x4c502d57534f4d492d5553444300000000000000000000000000000000000000"; // "LP-WSOMI-USDC" as bytes32

// Token Addresses
const WSOMI_ADDRESS = "0x046EDe9564A72571df6F5e44d0405360c0f4dCab";
const USDC_ADDRESS = "0x28BEc7E30E6faee657a03e19Bf1128AaD7632A00";

// Charged Particles
const PROTON_ADDRESS = "0x6487cb6570D43e3239A680fd607e6859307a0149";
const CHARGED_PARTICLES_ADDRESS = "0x2Ff4613a12570a77D88376A3e5d0FF68953b3fd8";

// QuickSwap Routers
const SWAP_ROUTER = "0x1582f6f3D26658F7208A799Be46e34b1f366CE44";
const LP_ROUTER = "0xfE02219e0578B1E4831CDE7C3CB36f71AEb4A833";

// Pack Parameters
const PACK_PRICE_SOMI = "0.1"; // Amount of native SOMI to spend
const PACK_TYPE = ethers.utils.formatBytes32String("LP-WSOMI-USDC");

// ============================================
// MAIN SCRIPT
// ============================================

async function main() {
    const [deployer] = await ethers.getSigners();
    
    console.log("============================================");
    console.log("Web3Packs LP Bundle Creation Script");
    console.log("============================================\n");
    
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Network: Somnia Mainnet (chainId: 5031)`);
    console.log(`Balance: ${ethers.utils.formatEther(await deployer.getBalance())} SOMI\n`);

    // Load ABIs
    let web3PacksV2Abi, web3PacksStateAbi, bundlerAbi;
    try {
        web3PacksV2Abi = JSON.parse(fs.readFileSync("./deployments/somnia/Web3PacksV2.json")).abi;
        web3PacksStateAbi = JSON.parse(fs.readFileSync("./deployments/somnia/Web3PacksState.json")).abi;
        bundlerAbi = JSON.parse(fs.readFileSync("./deployments/somnia/LPWSomiUsdc.json")).abi;
    } catch (e) {
        console.error("Failed to load ABIs. Make sure deployment files exist.");
        console.error(e.message);
        process.exit(1);
    }

    // Connect to contracts
    const web3PacksV2 = new ethers.Contract(WEB3PACKS_V2_ADDRESS, web3PacksV2Abi, deployer);
    const web3PacksState = new ethers.Contract(WEB3PACKS_STATE_ADDRESS, web3PacksStateAbi, deployer);
    const bundler = new ethers.Contract(BUNDLER_ADDRESS, bundlerAbi, deployer);

    // ============================================
    // PRE-FLIGHT CHECKS
    // ============================================
    console.log("--- Pre-flight Checks ---\n");

    // Check 1: Bundler registration
    const registeredBundler = await web3PacksState.getBundlerById(BUNDLER_ID);
    console.log(`Bundler registered: ${registeredBundler}`);
    console.log(`Expected: ${BUNDLER_ADDRESS}`);
    console.log(`Match: ${registeredBundler.toLowerCase() === BUNDLER_ADDRESS.toLowerCase()}`);

    if (registeredBundler.toLowerCase() !== BUNDLER_ADDRESS.toLowerCase()) {
        console.log("\n⚠️  Bundler not registered correctly!");
        console.log("Run: web3PacksState.registerBundlerId(BUNDLER_ID, BUNDLER_ADDRESS)");
    }

    // Check 2: WSOMI-USDC pool exists
    const factoryAbi = ["function poolByPair(address, address) view returns (address)"];
    const lpRouterAbi = ["function factory() view returns (address)"];
    const lpRouter = new ethers.Contract(LP_ROUTER, lpRouterAbi, deployer);
    const factory = await lpRouter.factory();
    const factoryContract = new ethers.Contract(factory, factoryAbi, deployer);
    const pool = await factoryContract.poolByPair(WSOMI_ADDRESS, USDC_ADDRESS);
    console.log(`\nWSOMI-USDC Pool: ${pool}`);
    
    if (pool === ethers.constants.AddressZero) {
        console.log("❌ NO POOL EXISTS! Create liquidity pool on QuickSwap first.");
        process.exit(1);
    }

    // ============================================
    // ATTEMPT BUNDLE
    // ============================================
    console.log("\n--- Attempting Bundle ---\n");

    const packPriceWei = ethers.utils.parseEther(PACK_PRICE_SOMI);
    
    const bundleParams = {
        bundleChunks: [
            {
                bundlerId: BUNDLER_ID,
                percentBasisPoints: 10000, // 100%
            }
        ],
        referrals: [],
        tokenMetaUri: "",
        lockState: {
            ERC20Timelock: 0,
            ERC721Timelock: 0,
        },
        packType: PACK_TYPE,
        purchaser: deployer.address,
        paymentAmount: 0, // Using msg.value instead
    };

    console.log("Bundle Parameters:");
    console.log(`  - Bundler ID: ${BUNDLER_ID}`);
    console.log(`  - Pack Type: LP-WSOMI-USDC`);
    console.log(`  - Payment: ${PACK_PRICE_SOMI} SOMI (native)`);
    console.log(`  - Purchaser: ${deployer.address}`);

    // Step 1: Simulate with callStatic
    console.log("\nStep 1: Simulating transaction...");
    try {
        const tokenId = await web3PacksV2.callStatic.bundle(
            bundleParams.bundleChunks,
            bundleParams.referrals,
            bundleParams.tokenMetaUri,
            bundleParams.lockState,
            bundleParams.packType,
            bundleParams.purchaser,
            bundleParams.paymentAmount,
            { value: packPriceWei }
        );
        console.log(`✅ Simulation SUCCESS! Token ID would be: ${tokenId.toString()}`);
    } catch (e) {
        console.log("❌ Simulation FAILED");
        console.log(`Error: ${e.reason || e.message}`);
        
        if (e.data && e.data !== "0x") {
            console.log(`Error data: ${e.data}`);
        }
        
        console.log("\n--- Debugging Info ---");
        console.log("The bundle is failing. Possible issues:");
        console.log("1. Bundler manager not set to Web3PacksV2");
        console.log("2. ChargedParticles wallet manager 'generic.B' not configured");
        console.log("3. ProtonC not properly linked to ChargedParticles");
        console.log("4. Insufficient liquidity in WSOMI-USDC pool");
        
        process.exit(1);
    }

    // Step 2: Send actual transaction
    console.log("\nStep 2: Sending transaction...");
    try {
        const tx = await web3PacksV2.bundle(
            bundleParams.bundleChunks,
            bundleParams.referrals,
            bundleParams.tokenMetaUri,
            bundleParams.lockState,
            bundleParams.packType,
            bundleParams.purchaser,
            bundleParams.paymentAmount,
            { 
                value: packPriceWei,
                gasLimit: 5000000 
            }
        );
        
        console.log(`Transaction hash: ${tx.hash}`);
        console.log("Waiting for confirmation...");
        
        const receipt = await tx.wait();
        console.log(`✅ Confirmed in block ${receipt.blockNumber}`);
        console.log(`Gas used: ${receipt.gasUsed.toString()}`);

        // Parse events
        const iface = new ethers.utils.Interface(web3PacksV2Abi);
        for (const log of receipt.logs) {
            try {
                const parsed = iface.parseLog(log);
                if (parsed.name === "PackBundled") {
                    console.log("\n============================================");
                    console.log("🎉 PACK CREATED SUCCESSFULLY!");
                    console.log("============================================");
                    console.log(`Token ID: ${parsed.args.tokenId.toString()}`);
                    console.log(`Purchaser: ${parsed.args.purchaser}`);
                    console.log(`Pack Type: ${ethers.utils.parseBytes32String(parsed.args.packType)}`);
                    console.log(`Total Payment: ${ethers.utils.formatEther(parsed.args.totalPayment)} SOMI`);
                    console.log(`Transaction: ${receipt.transactionHash}`);
                    console.log("============================================\n");
                }
            } catch (e) {}
        }

    } catch (e) {
        console.log("❌ Transaction FAILED");
        console.log(`Error: ${e.reason || e.message}`);
        
        if (e.transactionHash) {
            console.log(`\nCheck on explorer: https://somnia.blockscout.com/tx/${e.transactionHash}`);
        }
        
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });