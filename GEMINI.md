
Comprehensive guide to accept ETH or USDC from multiple source chains (Optimism, Mode, Ink, Binance, Polygon, Arbitrum, Solana, Bitcoin) and settle the payment on Mode, Ink, or Polygon — at the point of transaction — for a Web3 Pack purchase.

---

🧠 Overall Strategy

You’ll use:
Axelar + Squid Router (EVM chains)
Wormhole or Circle CCTP (Solana + USDC-native)
THORChain or intermediary service (Bitcoin)
Custom Contract on Mode/Ink/Polygon to receive and verify final payment

---

🔧 Key Components
1. Axelar GMP + Squid Integration (for EVM chains)
Use Axelar’s Gateway + GMP messaging to accept ETH or USDC from:
Optimism
Arbitrum
Binance Smart Chain
Polygon
Mode
Ink

Squid handles:
Swapping ETH → USDC
Cross-chain delivery to your contract on Mode/Ink/Polygon
Optional callback with payload (e.g., “Pack ID 123 for user X”)

---

2. Smart Contract Receiver on Mode, Ink, Polygon
Example: Web3PackReceiver.sol
contract Web3PackReceiver is AxelarExecutable {
    mapping(address => bool) public trustedSenders;

    constructor(address gateway_) AxelarExecutable(gateway_) {}

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        require(trustedSenders[sourceAddress], "Unauthorized");

        (address buyer, uint256 packId, uint256 amountPaid) = abi.decode(payload, (address, uint256, uint256));
        // Logic: mint pack, log event, etc.
    }
}

---

3. Route User Transaction via Squid
User selects:
Source Chain (e.g., Arbitrum)
Token (ETH or USDC)
Destination Chain (e.g., Mode)

Squid handles:
Swap (if needed)
Bridge
Calls your receiver contract with encoded payload

---

4. Solana Integration (USDC only)
Use Circle CCTP for native USDC bridging from Solana → EVM (Mode/Polygon).
Workflow:
User signs Solana USDC burn
Circle mints USDC on destination
Call your EVM contract with payload

Tooling:

Circle CCTP SDK

---

5. Bitcoin Integration (non-native)
BTC doesn't support smart contracts, so options are:
Custodial Wrapper (e.g., Wrapped BTC bridged via Portal or Ren)
THORChain: Accept BTC → auto-swap to USDC on destination EVM chain

If you're okay with wrapping:
Accept WBTC on supported chains (e.g., Ethereum or BSC)
Route via Squid to settle in USDC on Mode/Ink/Polygon

---

🔄 Unified Flow
🔗 User Flow
1. User selects payment chain & token (ETH or USDC)
2. Frontend calls Squid’s API → builds route
3. Transaction executes
4. Final USDC lands in your contract on Mode/Ink/Polygon
5. _execute() emits event or mints the Pack NFT/token

---

✅ Token Support

Chain	ETH	USDC	BTC	Method

Ethereum	✅	✅	WBTC	Squid + Axelar
Arbitrum	✅	✅	WBTC	Squid + Axelar
Optimism	✅	✅	WBTC	Squid + Axelar
Polygon	✅	✅	WBTC	Native
Binance	✅	✅	WBTC	Squid + Axelar
Mode	✅	✅	WBTC	Native
Ink	✅	✅	TBD	Native (or add custom Axelar support)
Solana	❌	✅	❌	Circle CCTP
Bitcoin	❌	❌	✅	THORChain / Wrapped BTC

---

📦 Smart Contract Checklist (on Mode/Ink/Polygon)
✅ Inherit from AxelarExecutable
✅ Handle _execute() with validation
✅ Log or mint pack token/NFT
✅ Whitelist allowed sourceAddress and sourceChain

---

🧪 Testing
Use Axelar Testnet: https://docs.axelar.dev/dev/testnet
Fork and deploy test receiver contracts
Simulate GMP delivery with Squid test routes

------------------

Axelar
An overview of the Axelar Network

Axelar Network delivers secure cross-chain communication for Web3.

Squid is made possible via Axelar's technology, and utilises Generalised Message Passing.

Squid's payments can be executed atomically with other cross-chain logic passed via Axelar, so users only need to submit a single transaction to carry out arbitrarily complex tasks.

Squid is the go-to liquidity module for developers building on top of Axelar. Wherever cross-chain payments are needed, Squid can be easily imported with a few lines of code.

For more detail, visit their documentation: https://docs.axelar.dev/

What is the difference between Squid and Axelar?
Axelar is like internet infrastructure for blockchains. It allows you to do anything between any chain, securely. Squid is an application which uses which uses Axelar's network to send assets between chains, swap them, and use them easily on each chain. Axelar makes it possible to connect all applications and users on all chains, but Squid actually connects them, letting users access apps with a single click, no matter where their wallet is.

------------------

Contracts
Squid's contract addresses are the same on every EVM chain.

Mainnet

SquidRouter

Chain -- address
------------------
All -- 0xce16F69375520ab01377ce7B88f5BA8C48F8D666
Blast -- 0x492751eC3c57141deb205eC2da8bFcb410738630
Fraxtal -- 0xDC3D8e1Abe590BCa428a8a2FC4CfDbD1AcF57Bd9
SquidMulticall -- 0xaD6Cea45f98444a922a2b4fE96b8C90F0862D2F4

------------------

# Cross-chain Swap Example

Here is an example of a cross-chain swap that you can run out of the box. Head to our [examples repo](https://github.com/0xsquid/examples/tree/main/V2/sdk/evmToEVMSwap), download the folder and run:

```
yarn install
```

Create a .env file and replace the values shared in the .env.example file. Then run

```
yarn start
```

This will run the index.ts below

```typescript

import { Squid } from "@0xsquid/sdk"; // Import Squid SDK
import { ethers } from "ethers"; // Import ethers v6
import * as dotenv from "dotenv"; // Import dotenv for environment variables
dotenv.config(); // Load environment variables from .env file

// Retrieve environment variables
const privateKey: string = process.env.PRIVATE_KEY!;
const integratorId: string = process.env.INTEGRATOR_ID!;
const FROM_CHAIN_RPC: string = process.env.FROM_CHAIN_RPC_ENDPOINT!;

if (!privateKey || !integratorId || !FROM_CHAIN_RPC) {
  console.error("Missing environment variables. Ensure PRIVATE_KEY, INTEGRATOR_ID, and FROM_CHAIN_RPC_ENDPOINT are set.");
  process.exit(1);
}

// Define chain and token addresses
const fromChainId = "56"; // BNB chain ID
const toChainId = "42161"; // Arbitrum chain ID
const fromToken = "0x55d398326f99059fF775485246999027B3197955"; // USDT token address on BNB
const toToken = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"; // USDC token address on Arbitrum

// Define the amount to be sent (in smallest unit, e.g., wei for Ethereum)
const amount = "1000000000000000";

// Set up JSON RPC provider and signer using the private key and RPC URL
// Create provider with the full URL
const provider = new ethers.JsonRpcProvider(FROM_CHAIN_RPC);
// Create wallet with the private key
const signer = new ethers.Wallet(privateKey, provider);

// Initialize the Squid client with the base URL and integrator ID
const getSDK = (): Squid => {
  const squid = new Squid({
    baseUrl: "https://v2.api.squidrouter.com",
    integratorId: integratorId,
  });
  return squid;
};

// Function to approve the transactionRequest.target to spend fromAmount of fromToken
const approveSpending = async (transactionRequestTarget: string, fromToken: string, fromAmount: string) => {
  const erc20Abi = [
    "function approve(address spender, uint256 amount) public returns (bool)"
  ];
  const tokenContract = new ethers.Contract(fromToken, erc20Abi, signer);
  try {
    const tx = await tokenContract.approve(transactionRequestTarget, fromAmount);
    await tx.wait();
    console.log(`Approved ${fromAmount} tokens for ${transactionRequestTarget}`);
  } catch (error) {
    console.error('Approval failed:', error);
    throw error;
  }
};

// Main function
(async () => {
  // Initialize Squid SDK
  const squid = getSDK();
  await squid.init();
  console.log("Initialized Squid SDK");

  // Set up parameters for swapping tokens
  const params = {
    fromAddress: await signer.getAddress(),
    fromChain: fromChainId,
    fromToken: fromToken,
    fromAmount: amount,
    toChain: toChainId,
    toToken: toToken,
    toAddress: await signer.getAddress()
  };

  console.log("Parameters:", params); // Printing the parameters for QA

  // Get the swap route using Squid SDK
  const { route, requestId } = await squid.getRoute(params);
  console.log("Calculated route:", route.estimate.toAmount);

  // Get the transaction request from route
  if (!route.transactionRequest) {
    console.error("No transaction request in route");
    process.exit(1);
  }

  // For SquidData objects, we need to check what type it is and extract the target
  let target: string;
  if ('target' in route.transactionRequest) {
    target = route.transactionRequest.target;
  } else {
    console.error("Cannot determine target address from transaction request");
    console.log("Transaction request:", route.transactionRequest);
    process.exit(1);
  }

  // Approve the target to spend fromAmount of fromToken
  await approveSpending(target, fromToken, amount);

  // Execute the swap transaction
  const txResponse = await squid.executeRoute({
    signer: signer as any, // Cast to any to bypass type checking issues
    route,
  });

  // Handle the transaction response - could be an ethers v6 TransactionResponse or something else
  let txHash: string = 'unknown';

  if (txResponse && typeof txResponse === 'object') {
    if ('hash' in txResponse) {
      // This is an ethers TransactionResponse
      txHash = txResponse.hash as string;
      await (txResponse as any).wait?.(); // Wait for the transaction to be mined if possible
    } else if ('transactionHash' in txResponse) {
      // This might be a v5 style response or custom Squid format
      txHash = (txResponse as any).transactionHash as string;
    } else {
      // Fallback - try to find a hash property
      txHash = (txResponse as any).hash as string || 'unknown';
    }
  }

  // Show the transaction receipt with Axelarscan link
  const axelarScanLink = "https://axelarscan.io/gmp/" + txHash;
  console.log(`Finished! Check Axelarscan for details: ${axelarScanLink}`);

  // Wait a few seconds before checking the status
  await new Promise((resolve) => setTimeout(resolve, 5000));

  // Parameters for checking the status of the transaction
  const getStatusParams = {
    transactionId: txHash,
    requestId: requestId,
    integratorId: integratorId,
    fromChainId: fromChainId,
    toChainId: toChainId,
  };

  const completedStatuses = ["success", "partial_success", "needs_gas", "not_found"];
  const maxRetries = 10; // Maximum number of retries for status check
  let retryCount = 0;

  // Get the initial status
  let status = await squid.getStatus(getStatusParams);
  console.log(`Initial route status: ${status.squidTransactionStatus}`);

  // Loop to check the transaction status until it is completed or max retries are reached
  do {
    try {
      // Wait a few seconds before checking the status
      await new Promise((resolve) => setTimeout(resolve, 5000));

      // Retrieve the transaction's route status
      status = await squid.getStatus(getStatusParams);

      // Display the route status
      console.log(`Route status: ${status.squidTransactionStatus}`);

    } catch (error: unknown) {
      // Handle error if the transaction status is not found
      if (error instanceof Error && (error as any).response && (error as any).response.status === 404) {
        retryCount++;
        if (retryCount >= maxRetries) {
          console.error("Max retries reached. Transaction not found.");
          break;
        }
        console.log("Transaction not found. Retrying...");
        continue;
      } else {
        throw error;
      }
    }

  } while (status && !completedStatuses.includes(status.squidTransactionStatus));

  // Wait for the transaction to be executed
  console.log("Swap transaction executed:", txHash);
})();
```

------------------

# Cross-chain NFT Purchase Example

This example walks you through how to implement the SDK to purchase an NFT on any chain.

Download the full example [**here**](https://github.com/0xsquid/examples/blob/main/V2/sdk/oldExamples/buyNftFromAnyChain/src/index.ts)**.**

```typescript
import { Squid } from "@0xsquid/sdk";
import { ethers } from "ethers";

// Environment
// add to a file named ".env" to prevent them being uploaded to github
import * as dotenv from "dotenv";
dotenv.config();
const avaxRpcEndpoint = process.env.AVAX_RPC_ENDPOINT;
const privateKey = process.env.PRIVATE_KEY;

// ABIs
import erc1155Abi from "../abi/erc1155Abi";
import erc20Abi from "../abi/erc20Abi";
import treasureMarketplaceAbi from "../abi/treasureMarketplaceAbi";

// Squid call types for multicall
const SquidCallType = {
  DEFAULT: 0,
  FULL_TOKEN_BALANCE: 1,
  FULL_NATIVE_BALANCE: 2,
  COLLECT_TOKEN_BALANCE: 3,
};

// addresses and IDs
const avalancheId = 43114;
const arbitrumId = 42161;
const nativeToken = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const squidMulticall = "0x4fd39C9E151e50580779bd04B1f7eCc310079fd3";
const magicToken = "0x539bdE0d7Dbd336b79148AA742883198BBF60342";
const treasureAddress = "0x09986b4e255b3c548041a30a2ee312fe176731c2"; // treasure contract
const moonrockNftAddress = "0xc5295c6a183f29b7c962df076819d44e0076860e";
const moonrockOwner = "0xa5c53eb116EC0CE355D8be38b0EB424ce520A4db";

// amount of AVAX to send (currently 0.05 AVAX)
const amount = "30000000000000000";

const getSDK = () => {
  const squid = new Squid({
    baseUrl: "https://v2.api.squidrouter.com",
    integratorId: process.env.INTEGRATOR_ID,
  });
  return squid;
};

(async () => {
  // set up your RPC provider and signer
  const provider = new ethers.JsonRpcProvider(avaxRpcEndpoint);
  const signer = new ethers.Wallet(privateKey, provider);
  console.log("Signer address: ", signer.address);

  // instantiate the SDK
  const squid = getSDK();
  // init the SDK
  await squid.init();
  console.log("Squid inited");

  // Generate the encoded data to approve the Treasure contract to spend Magic
  const erc20ContractInterface = new ethers.Interface(erc20Abi);
  const approveEncodeData = erc20ContractInterface.encodeFunctionData(
    "approve",
    [treasureAddress, "0"]
  );

  // Generate the encoded data to buy the NFT on Treasure
  // This example buys a MoonRock NFT on Treasure on mainnet
  // https://trove.treasure.lol/collection/smol-treasures/1
  const treasureMarketplaceInterface = new ethers.Interface(
    treasureMarketplaceAbi
  );
  const _buyItemParams = {
    nftAddress: moonrockNftAddress,
    tokenId: 1,
    owner: moonrockOwner,
    quantity: 1,
    maxPricePerItem: "990000000000000000",
    paymentToken: magicToken,
    usinEth: false,
  };
  const buyMoonRockNftEncodeData =
    treasureMarketplaceInterface.encodeFunctionData("buyItems", [
      [_buyItemParams],
    ]);

  // Generate the encoded data to transfer the NFT to signer's address
  const erc1155Interface = new ethers.Interface(erc1155Abi);
  const transferNftEncodeData = erc1155Interface.encodeFunctionData(
    "safeTransferFrom",
    [squidMulticall, signer.address, 1, 1, 0x00]
  );

  // Generate the encoded data to send any remaining Magic back to signer's address
  const transferMagicEncodeData = erc20ContractInterface.encodeFunctionData(
    "transfer",
    [signer.address, "0"]
  );

  const { route, requestId } = await squid.getRoute({
    toAddress: signer.address,
    fromChain: avalancheId,
    fromToken: nativeToken,
    fromAmount: amount,
    toChain: arbitrumId,
    toToken: magicToken,
    slippage: 1,   //optional, Squid will dynamically calculate if removed
    // enableExpress: false, // default is true on all chains except Ethereum
    postHook: [
      description: "Buy Milady 2039 on Ethereum"
      {
        callType: SquidCallType.FULL_TOKEN_BALANCE,
        target: magicToken,
        value: "0",
        callData: approveEncodeData,
        payload: {
          tokenAddress: magicToken,
          inputPos: 1,
        },
        estimatedGas: "50000",
      },
      {
        callType: SquidCallType.DEFAULT,
        target: treasureAddress,
        value: "0",
        callData: buyMoonRockNftEncodeData,
        payload: {
          tokenAddress: "1",
          inputPos: 1,
        },
        estimatedGas: "80000",
      },
      {
        callType: SquidCallType.DEFAULT,
        target: moonrockNftAddress,
        value: "0",
        callData: transferNftEncodeData,
        payload: {
          tokenAddress: "0x",
          inputPos: 1,
        },
        estimatedGas: "50000",
      },
      {
        callType: SquidCallType.FULL_TOKEN_BALANCE, // transfer any remaining MAGIC to the user's account
        target: magicToken,
        value: "0",
        callData: transferMagicEncodeData,
        payload: {
          tokenAddress: magicToken,
          inputPos: 1,
        },
        estimatedGas: "50000",
      },
    ],
  });

  const tx = (await squid.executeRoute({
    signer,
    route,
  })) as unknown as ethers.TransactionResponse;
  const txReceipt = await tx.wait();

  const axelarScanLink = "https://axelarscan.io/gmp/" + txReceipt.hash;
  console.log(
    "Finished! Please check Axelarscan for more details: ",
    axelarScanLink,
    "\n"
  );

  console.log(
    "Track status via API call to: https://api.squidrouter.com/v1/status?transactionId=" +
      txReceipt.hash,
    "\n"
  );

  // It's best to wait a few seconds before checking the status
  await new Promise((resolve) => setTimeout(resolve, 5000));

  const status = await squid.getStatus({
    transactionId: txReceipt.hash,
  });

  console.log("Status: ", status);
})();
```

------------------

---
description: This method aims to provide the status of the transaction
---

# Get Route Status

## Get Route Status

Squid combines Axelar's infrastructure as well as  bespoke on-chain analytics to provide status of cross-chain transactions. You can access this status using the `getStatus` method on our SDK.

You can also check completion of most cross chain transactions on Squid by copying the transaction hash into [AxelarScan](https://axelarscan.io/). Note, for some Cosmos transactions and others in the future this will not work.

### Usage

```typescript
const status = await squid.getStatus({
    transactionId,
    requestId,
    integratorId,
    fromChainId,
    toChainId,
    quoteId, // Including the quote ID will enable us to share volume stats with your integrator ID
})
```

### Request Parameters

| Parameter       | Type   | Required | Description                                                                                                                                    |
| --------------- | ------ | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `transactionId` | string | Yes      | The transaction hash                                                                                                                           |
| `requestId`     | string | No       | The request ID (legacy parameter)                                                                                                              |
| `integratorId`  | string | Yes      | Your integrator ID                                                                                                                             |
| `fromChainId`   | string | Yes      | The source chain ID                                                                                                                            |
| `toChainId`     | string | Yes      | The destination chain ID                                                                                                                       |
| `quoteId`       | string | Yes      | The quote ID from the route response. Passing this parameter will enable volume and token activity sharing with integrators in the near future |
| bridgeType      | string | no       |                                                                                                                                                |

#### Getting Quote ID from Route Response

The `quoteId` can be found at the top level of the route response. Including this parameter in status requests will enable volume and specific token activity sharing with integrators in the near future:

```json
{
    "route": {
        "quoteId": "6f388be5205ee044cd7fd5047a4ce72e"
    }
}
```

### Understanding squidTransactionStatus

The most important response param is `squidTransactionStatus`. This param will tell you what to show the user. There are 6 possible states:

```typescript
{
  SUCCESS = "success",
  NEEDS_GAS = "needs_gas",
  ONGOING = "ongoing",
  PARTIAL_SUCCESS = "partial_success",
  NOT_FOUND = "not_found",
  REFUND = "refund"
}
```

#### SUCCESS

This indicates the transaction has completed on all chains. Whether a single chain, 2 chain or 3 chain call, the swap, stake, NFT purchase, bridge etc. has completed without any reversions and the user has received the intended funds.

#### NEEDS\_GAS

This state is specific for Axelar transactions. If the gas price has spiked on the destination chain and execution cannot complete, Squid will return this status. The best user flow in this case is to send the user to Axelarscan to view the paused transaction.

#### ONGOING

There is nothing wrong, nothing to do, just relax and wait. The transaction should have an `estimatedRouteDuration` in seconds that you can read from the `/route` response. We generally recommend contacting support after either 15 minutes has passed, or double the `estimatedRouteDuration`, whichever is larger.

#### PARTIAL\_SUCCESS

This status indicates that the transaction has completed some of its steps. Currently, there is only one case that could cause this state. In the future there will be many, but we will provide more metadata around the `PARTIAL_SUCCESS`. For now, this is what has happened:

* The source chain transaction successfully executed, along with any swaps or contract calls.
* The destination chain transaction has executed, but reverted during execution. This is usually due to slippage on volatile assets, but if you are trying to buy an NFT or do some cross-chain staking, then it could indicate that the custom hook had a failure.

If there is a partial success, the user will have received the bridged token in their wallet on the destination chain. In most cases this is axlUSDC.

#### NOT\_FOUND

The Squid API cannot find an on-chain record of the transaction. This is usually due to our various services or service providers not having indexed the completed transaction. This state is often returned for 5-10 seconds after the transaction was executed, while chain indexing occurs.

This should not persist after maximum a few minutes (some chains such as Filecoin take a very long time to index, and for block inclusion). If it does, then get in touch with us on Discord.

#### REFUND

This status is specific to failed Coral routes. When a Coral transaction fails, the funds are automatically refunded on the source chain. This is the default behavior for Coral routes when passing the user's address as the `fromAddress`.

**How Coral refunds work:**

* Funds are always transferred from the `msg.sender` on the source chain (this could be the user for direct calls to Coral, or a smart contract like Multicall)
* When refunded, funds are sent to the `order.fromAddress` which is encoded to the user, not the caller
* The `fromAddress` from the route request is used as the `order.fromAddress` for refunds
* This ensures that even if the transaction was initiated through a smart contract, the refund goes to the actual user

### How to Share Block Explorer Links

Generally, the best thing to do is to share `https://axelarscan.io/gmp/<txHash>` with a user.

With the caveat that if you are doing a transaction between two Cosmos chains, this link may not be correct. For now we simply recommend you always using this approach, we are upgrading our status capability and the status endpoint will always return the correct block explorer link to share.

### Response Parameters

The response includes detailed information about both source and destination chains, transaction URLs, timing data, and the current status.

#### Example Response

```json
{
    "id": "0x7591aa38d646ac26b57f7235836cb7e7b63a32534bdd2e5dcecf06136744a94d",
    "status": "success",
    "gasStatus": "",
    "isGMPTransaction": false,
    "axelarTransactionUrl": "",
    "fromChain": {
        "transactionId": "0x7591aa38d646ac26b57f7235836cb7e7b63a32534bdd2e5dcecf06136744a94d",
        "blockNumber": "339763809",
        "callEventStatus": "",
        "callEventLog": [],
        "chainData": {
            "id": "42161",
            "chainId": "42161",
            "networkIdentifier": "arbitrum",
            "chainName": "Chain 42161",
            "axelarChainName": "Arbitrum",
            "type": "evm",
            "networkName": "Arbitrum",
            "nativeCurrency": {
                "name": "Arbitrum",
                "symbol": "ETH",
                "decimals": 18,
                "icon": "https://raw.githubusercontent.com/axelarnetwork/axelar-docs/main/public/images/chains/arbitrum.svg"
            },
            "chainIconURI": "https://raw.githubusercontent.com/0xsquid/assets/main/images/webp128/chains/arbitrum.webp",
            "blockExplorerUrls": [
                "https://arbiscan.io/"
            ],
            "swapAmountForGas": "2000000",
            "sameChainSwapsSupported": true,
            "compliance": {
                "trmIdentifier": "arbitrum"
            },
            "boostSupported": true,
            "enableBoostByDefault": true,
            "rpcList": [
                "https://arb1.arbitrum.io/rpc"
            ],
            "visible": true,
            "chainNativeContracts": {
                "wrappedNativeToken": "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
                "ensRegistry": "",
                "multicall": "0xcA11bde05977b3631167028862bE2a173976CA11",
                "usdcToken": "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8"
            },
            "feeCurrencies": [],
            "currencies": [],
            "features": []
        },
        "transactionUrl": "https://arbiscan.io/tx/0x7591aa38d646ac26b57f7235836cb7e7b63a32534bdd2e5dcecf06136744a94d"
    },
    "toChain": {
        "transactionId": "0x4579e4df67994f4b1790d51c1586cbe79048dafd9c69467de1ecc887b4a25186",
        "blockNumber": "30616439",
        "callEventStatus": "",
        "callEventLog": [],
        "chainData": {
            "id": "8453",
            "chainId": "8453",
            "networkIdentifier": "base",
            "chainName": "Chain 8453",
            "axelarChainName": "base",
            "type": "evm",
            "networkName": "Base",
            "nativeCurrency": {
                "name": "Base",
                "symbol": "ETH",
                "decimals": 18,
                "icon": "https://raw.githubusercontent.com/axelarnetwork/axelar-docs/main/public/images/chains/base.svg"
            },
            "chainIconURI": "https://raw.githubusercontent.com/0xsquid/assets/main/images/chains/base.svg",
            "blockExplorerUrls": [
                "https://basescan.org/"
            ],
            "swapAmountForGas": "2000000",
            "sameChainSwapsSupported": true,
            "boostSupported": true,
            "enableBoostByDefault": true,
            "rpcList": [
                "https://developer-access-mainnet.base.org"
            ],
            "visible": true,
            "chainNativeContracts": {
                "wrappedNativeToken": "0x4200000000000000000000000000000000000006",
                "ensRegistry": "",
                "multicall": "0xcA11bde05977b3631167028862bE2a173976CA11",
                "usdcToken": "0x66627F389ae46D881773B7131139b2411980E09E"
            },
            "feeCurrencies": [],
            "currencies": [],
            "features": [],
            "axelarFeeMultiplier": 150
        },
        "transactionUrl": "https://basescan.org/tx/0x4579e4df67994f4b1790d51c1586cbe79048dafd9c69467de1ecc887b4a25186"
    },
    "timeSpent": {
        "total": 2
    },
    "routeStatus": [
        {
            "chainId": "42161",
            "txHash": "0x7591aa38d646ac26b57f7235836cb7e7b63a32534bdd2e5dcecf06136744a94d",
            "status": "success",
            "action": "send"
        },
        {
            "chainId": "8453",
            "txHash": "0x4579e4df67994f4b1790d51c1586cbe79048dafd9c69467de1ecc887b4a25186",
            "status": "success",
            "action": "call"
        }
    ],
    "squidTransactionStatus": "success"
}
```

-------------------

# Key Concepts

## Overview

These concepts are functionalities that persist throughout Squid's Widget, API, and SDK that enable a seamless cross-chain experience for both users and developer. Please read through each feature to understand how they are implemented across Squid&#x20;

## Squid Functionality

The functionality of the Squid boils down to **3 main functionalities**:

1. [**Route Requests**](../old-v2-documentation-deprecated/key-concepts/get-a-route)**(Fetching a Route):** Calculating the most optimized path from one asset to another.
2. [**Route Execution**](../old-v2-documentation-deprecated/key-concepts/execute-the-route)**:** The submission and execution of that path on chain.
3. [**Transaction Status**](../old-v2-documentation-deprecated/key-concepts/track-status)**:** The validation that the transaction has been completed.

There are **3 advanced functionalities** enhance Squid's API capabilities:

1. [**Transaction Hooks**](https://app.gitbook.com/o/bX90yMGYDBu3T1Hqg4EA/s/tXbXyuWIO2PwzNc5Dets/) **(Pre/Post):** Allow transactions to be prepended(prehook) or appended(posthook) to asset transfers for a user. Think unstaking then transferring an asset or transfering an asset across chain then staking.
2. [**Boost:** ](../old-v2-documentation-deprecated/key-concepts/boost)Squids novel boost functionality allows cross-chain transactions to be settled in less than 20seconds by using an intent-model, a smart contract overlay which allows a provider to optimistically fulfill a transaction.
3. [**Collecting Fees**](../old-v2-documentation-deprecated/key-concepts/collect-fees-1)**:** Always integrators to collect fees associated with transactions. Note, this function is currently not available for v2 yet.

#### **A Note On Up-Time**

Squid aims for 100% up-time with multiple guardrails in place to prevent unintended downtime. If you believe Squid may be experiencing downtime you can check our [status page ](https://status.v2.api.squidrouter.com)to see if there are any outages.

---------------
# Route Request Parameters

Building with Squid, fundamentally starts with requesting a route.&#x20;

The `getRoute` type is used to define the parameters required for bridging assets between different blockchain networks.&#x20;

```typescript


const params = {
  fromChain: number | string; //the chainID assets are being bridged FROM
  toChain: number | string; //the chainID assets are being bridged TO
  fromToken: string;  //the asset address being swapped FROM, "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" for native assets
  toToken: string;  // The asset address being swapped TO, "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" for native assets
  fromAmount: string; // The unadjusted decimal amount assets
  fromAddress: string; // The address FROM which assets are being sent to be bridged
  toAddress: string; // The address TO which bridged assets will be sent to
  slippage: number; //OPTIONAL, If set it determines the max slippage across the route (0.01-99.99) 1 = 1% slippage.
  quoteOnly: boolean; //OPTIONAL, If true, returns only a quote for the route. Omits transaction data needed for execution. Defaults to false
  fallbackAddresses?:{
    //For Cosmos routes where either the source or destination chains are not of coinType 118, the SDK necessitates an additional argument.
    ///This argument is fallbackAddresses, which is an array of objects containing an address and its associated coin type.
    //See more here
    coinType: number;
    address: string;
  };
};

```

## Parameter Summaries

* **fromChain** (`number | string`): The chain ID of the network from which assets are being bridged.
* **toChain** (`number | string`): The chain ID of the network to which assets are being bridged.
* **fromToken** (`string`): The address of the asset being swapped from. Use "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" for native assets.
* **toToken** (`string`): The address of the asset being swapped to. Use "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" for native assets.
* **fromAmount** (`string`): The unadjusted decimal amount of assets being transferred.
* **fromAddress** (`string`): The address from which assets are being sent for bridging.
* **toAddress** (`string`): The address to which bridged assets will be sent.
* **slippage** (`number`, optional): Maximum allowable slippage across the route (range: 0.01-99.99). A value of 1 represents 1% slippage.
* **quoteOnly** (`boolean`, optional): If true, only a quote for the route is returned without transaction data needed for execution. Defaults to false.
* **customContractCalls** (`ContractCall[] | CustomCosmosContractCall[]`, optional): Custom contract calls to be included in the route.
* **fallbackAddresses** (`{ coinType: number; address: string; }[]`, optional): For Cosmos routes where the source or destination chains are not of coinType 118. Requires an array of objects containing an address and its associated coin type.
* **bypassGuardrails** (boolean): This allows you to waive Squid's slippage guardrails and perform any route with slippage. **NOTE: If this param is set to true, the integrator is liable for any loss of funds during the route.**&#x20;

---------------
# General message passing (GMP)

Squid composes swaps using Axelar's _general message passing_ capability. This allows users to execute cross-contract calls using any token without signing a second transaction on the destination chain.

Example use cases:

* Zap into a liquidity pool on another chain
* Buy any NFT on any chain with one click
* Enter a launchpad on a different chain
* Buy an item on a gaming marketplace and send the item to the game you want to play
* Getting tokens on the Avalanche C-chain and sending to a shard

---------------
# Transaction times and fees

## Fees

Squid currently charges no fees. The user will only pay gas fees on source and destination chains.

It is possible for our partners to charge fees via our SDK or API. Partners can elect a % fee they would like to charge, and Squid will receive a portion of this fee.&#x20;



### Source Chain transactions

#### EVM

Fees are comprised of the following and are paid in Native Gas

* Gas amount needed for any swaps, approvals and transfers
* If the "from token" is the Native gas token, this amount is also added to the gas payment
* The execution fees for the destination chain

#### Cosmos

Cosmos transactions are different to EVM transaction as the destination chain gas fees are taken out of the bridge token. e.g for a route that is Osmo:Osmosis > ETH:Ethereum, usually the bridge token will be axlUSDC, and this is where the GMP (bridge) fee will be taken from. If the route is axlWETH > WETH the fee will be taken in WETH.\
Gas payment for source chain will be only the amount needed for the execution on the Cosmos chain, all IBC relaying comes at 0 cost.&#x20;



### General message passing fees (swap on destination chain)

Just like the source chain transactions, the amount gas charged is calculated base off how many swaps, transfers and approvals there are.&#x20;

For transactions where there is a swap on the destination chain, fees are paid using the Native token on the source chain. This fee is paid to Axelar's relayers, who trustlessly pass messages and proofs across chains.&#x20;

Axelar's relayers hold gas on every chain and provide a pricing API which Squid calls to get the expected gas price for a trade. For example if the destination trade will probably cost 50 cents of AVAX in gas, then Squid will instruct the user to pay Axelar's gas service 50 cents worth of Moonbeam, as per the pricing which Axelar gives our backend.

### What happens in the case of a spike in gas fees

If the cost of gas on the destination chain doubles while your cross chain transaction is being approved by Axelar, there is a chance you will either need to wait for the gas prices to lower again, or you will need to add gas to your transaction. The best way of doing this is by going to AxelarScan and searching for your transaction, using the transaction hash from the source chain. AxelarScan will show a call to action to "Add gas" where you can login with Metamask, or the relevant wallet, and help get your transaction to the finish line.

[AxelarScan on Mainnet](https://axelarscan.io/)

[AxelarScan on Testnet](https://testnet.axelarscan.io/)

Squid also plans to expose the ability to add gas to a transaction by wrapping the Axelar SDK.

## Boost Fees&#x20;

Boost fee is a small dynamic premium that can be optionally paid for faster cross-chain bridge transactions, this is a service provided by Axelar (express), Axelar's relayers will determine if enough gas is paid to be boosted. The amount can vary dependant on the current price of gas. Details of the boost pice can be found on the Squid widget details page or the Squid API response.\
For more information read about boost here:

* [https://docs.squidrouter.com/boost](https://docs.squidrouter.com/boost)
* [https://docs.axelar.dev/dev/general-message-passing/express](https://docs.axelar.dev/dev/general-message-passing/express)



### CCTP Noble Fees

CCTP bridge is not considered a transfer and there is no fee for this.



## Transaction times

Most transactions on Squid use [boost](../../old-v2-documentation-deprecated/key-concepts/boost "mention"). Which brings transactions times down to 0-20 seconds!&#x20;

If Boost is not supported for a route, transaction times are dependent on the source chain finality:

* From Ethereum: 16 min
* From Rollups: 22 min
* From other chains: 30seconds-2min

----------------
# Fallback behaviour on failed transactions

### What happens when the destination transaction fails?

There are two cases where a failure can occur across chain:

1. Prices have moved drastically while waiting for the cross chain message to be executed, further than slippage has allowed for.&#x20;
2. If a [contract call](../squid-v1-docs/sdk/contract-calls) is requested by the integrator, and the contract call is faulty, the entire destination chain transaction will fail.&#x20;

In either of these cases, the Squid smart contracts will revert and send the bridged tokens to the toAddress. Currently, axlUSDC is the only bridged token used in routes, so the user will receive axlUSDC. The user will then need to swap axlUSDC to their desired token manually. Squid is developing a recovery which streamlines this process, but for now the user must visit a local DEX, or use Squid to swap back across chains.

### What happens if Axelar goes offline for a scheduled upgrade or fails?

Transactions are safe, but will be stuck "in transit" until the Axelar Network comes back online.&#x20;

--------------
---
description: An overview of the Axelar Network
---

# Axelar

[Axelar Network](https://axelar.network) delivers secure cross-chain communication for Web3.&#x20;

Squid is made possible via Axelar's technology, and utilises _Generalised Message Passing_.&#x20;

Squid's payments can be executed atomically with other cross-chain logic passed via Axelar, so users only need to submit a single transaction to carry out arbitrarily complex tasks.

Squid is the go-to liquidity module for developers building on top of Axelar. Wherever cross-chain payments are needed, Squid can be easily imported with a few lines of code.&#x20;

For more detail, visit their documentation: [https://docs.axelar.dev/](https://docs.axelar.dev/)

### What is the difference between Squid and Axelar?

Axelar is like internet infrastructure for blockchains. It allows you to do _anything_ between any chain, securely. Squid is an application which uses which uses Axelar's network to send assets between chains, swap them, and use them easily on each chain. Axelar makes it _possible_ to connect all applications and users on all chains, but Squid actually _connects_ them, letting users access apps with a single click, no matter where their wallet is.
