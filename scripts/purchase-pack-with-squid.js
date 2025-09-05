const { Squid } = require("@0xsquid/sdk");
const { ethers } = require("ethers");
const dotenv = require("dotenv");

// Load environment variables from .env file
dotenv.config();

// ENVIRONMENT VARIABLES
// Ensure you have a .env file with the following variables
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const INTEGRATOR_ID = process.env.INTEGRATOR_ID; // Your Squid integrator ID
const FROM_CHAIN_RPC = process.env.FROM_CHAIN_RPC; // e.g., https://polygon-rpc.com
const TO_CHAIN_RPC = process.env.TO_CHAIN_RPC;     // e.g., https://mainnet.mode.network

// CONTRACT AND TOKEN ADDRESSES
// These need to be updated for your specific deployment and desired route
const web3PacksV2Address = "0xYOUR_WEB3PACKSV2_CONTRACT_ADDRESS"; // TODO: Update this
const wethAddress = "0x4200000000000000000000000000000000000006"; // WETH on Mode Mainnet, for example

// ROUTE PARAMETERS
const fromChainId = "137"; // Polygon
const toChainId = "34443";   // Mode Mainnet
const fromToken = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // Native MATIC
const fromAmount = ethers.utils.parseEther("0.1").toString(); // Amount of source token to send

// BUNDLE PARAMETERS
// These are the arguments for your Web3PacksV2.bundle() function
const bundleParams = {
    bundleChunks: [],
    referrals: [],
    tokenMetaUri: "ipfs://your-metadata-hash", // TODO: Update this
    lockState: { lockUntil: 0, isPermanent: false },
    packType: ethers.utils.formatBytes32String("MyPack"),
    purchaser: null, // Will be set to the signer's address
    paymentAmount: fromAmount, // This will be updated with the received amount after swap
};

// Squid Call Type for postHook
const SquidCallType = {
    DEFAULT: 0,
    FULL_TOKEN_BALANCE: 1,
    FULL_NATIVE_BALANCE: 2,
    COLLECT_TOKEN_BALANCE: 3,
};

/**
 * Main execution function
 */
(async () => {
    // Validate environment variables
    if (!PRIVATE_KEY || !INTEGRATOR_ID || !FROM_CHAIN_RPC || !TO_CHAIN_RPC) {
        console.error("Missing environment variables. Please check your .env file.");
        process.exit(1);
    }

    // Set up providers and signers
    const fromProvider = new ethers.providers.JsonRpcProvider(FROM_CHAIN_RPC);
    const toProvider = new ethers.providers.JsonRpcProvider(TO_CHAIN_RPC);
    const signer = new ethers.Wallet(PRIVATE_KEY, fromProvider);
    bundleParams.purchaser = signer.address; // Set purchaser address

    // Initialize Squid SDK
    const squid = new Squid({
        baseUrl: "https://v2.api.squidrouter.com",
        integratorId: INTEGRATOR_ID,
    });
    await squid.init();
    console.log("Squid SDK initialized.");

    // ABIs for encoding the postHook calls
    const web3PacksAbi = [
        "function bundle(tuple(bytes32,uint256)[] bundleChunks, address[] referrals, string tokenMetaUri, tuple(uint256,bool) lockState, bytes32 packType, address purchaser, uint256 paymentAmount)",
    ];
    const erc20Abi = ["function approve(address spender, uint256 amount)"];

    const web3PacksInterface = new ethers.utils.Interface(web3PacksAbi);
    const erc20Interface = new ethers.utils.Interface(erc20Abi);

    // 1. DEFINE THE POST-HOOK
    // The postHook is an array of contract calls that will be executed on the destination chain after the swap and bridge.
    const postHook = [
        {
            callType: SquidCallType.FULL_TOKEN_BALANCE, // Use the full balance of the bridged WETH
            target: wethAddress, // The WETH contract address on the destination chain
            value: "0", // No native value sent
            callData: erc20Interface.encodeFunctionData("approve", [
                web3PacksV2Address, // Spender (our contract)
                fromAmount, // Amount to approve (will be replaced by Squid's contracts)
            ]),
            payload: {
                tokenAddress: wethAddress,
                inputPos: 1, // The approval amount is the 2nd argument of the approve function (index 1)
            },
            estimatedGas: "50000",
        },
        {
            callType: SquidCallType.FULL_TOKEN_BALANCE, // Use the full balance of the bridged WETH for payment
            target: web3PacksV2Address, // Our Web3PacksV2 contract
            value: "0",
            callData: web3PacksInterface.encodeFunctionData("bundle", [
                bundleParams.bundleChunks,
                bundleParams.referrals,
                bundleParams.tokenMetaUri,
                Object.values(bundleParams.lockState),
                bundleParams.packType,
                bundleParams.purchaser,
                bundleParams.paymentAmount, // Amount (will be replaced by Squid's contracts)
            ]),
            payload: {
                tokenAddress: wethAddress,
                inputPos: 6, // The paymentAmount is the 7th argument of the bundle function (index 6)
            },
            estimatedGas: "250000", // Estimate gas for the bundle function
        },
    ];

    // 2. GET THE ROUTE FROM SQUID
    console.log("\nGetting route from Squid...");
    const params = {
        fromAddress: signer.address,
        fromChain: fromChainId,
        fromToken: fromToken,
        fromAmount: fromAmount,
        toChain: toChainId,
        toToken: wethAddress, // We want to receive WETH on the destination chain
        toAddress: signer.address, // The WETH will be bridged to the user's address
        slippage: 1, // 1% slippage
        postHook: postHook,
    };

    const { route, requestId } = await squid.getRoute(params);
    console.log("Route received. Expected output:", ethers.utils.formatUnits(route.estimate.toAmount, 18), "WETH");

    // 3. EXECUTE THE ROUTE
    console.log("\nExecuting route...");
    const tx = await squid.executeRoute({ signer, route });
    const txReceipt = await tx.wait();

    const axelarScanLink = "https://axelarscan.io/gmp/" + txReceipt.transactionHash;
    console.log(`\nFinished! Transaction hash: ${txReceipt.transactionHash}`);
    console.log(`Track cross-chain status at: ${axelarScanLink}\n`);

    // 4. CHECK FINAL STATUS
    let status = await squid.getStatus({ transactionId: txReceipt.transactionHash });
    console.log(`Initial status: ${status.squidTransactionStatus}`);

    const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

    while (status.squidTransactionStatus !== "success" && status.squidTransactionStatus !== "partial_success" && status.squidTransactionStatus !== "needs_gas") {
        console.log(`Status is: ${status.squidTransactionStatus}, waiting...`);
        await sleep(5000); // Wait 5 seconds
        status = await squid.getStatus({ transactionId: txReceipt.transactionHash });
    }

    console.log(`\nFinal status: ${status.squidTransactionStatus}`);
    console.log("Pack purchase executed successfully!");

})();
