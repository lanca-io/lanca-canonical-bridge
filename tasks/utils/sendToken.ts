import { getNetworkEnvKey } from "@concero/contract-utils";
import { decodeEventLog, formatEther, parseUnits } from "viem";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";
import { monitorBridgeDelivered } from "./monitorBridgeDelivered";

interface SendTokenParams {
	srcChain: string;
	dstChain: string;
	amount: string;
	receiver?: string;
}

export async function sendToken(params: SendTokenParams): Promise<void> {
	const { srcChain, dstChain, amount, receiver } = params;

	const srcNetwork = conceroNetworks[srcChain as keyof typeof conceroNetworks];
	const { viemChain, type, chainSelector: srcChainSelector } = srcNetwork;

	const dstNetwork = conceroNetworks[dstChain as keyof typeof conceroNetworks];
	if (!dstNetwork) {
		err(`Destination network ${dstChain} not found`, "sendToken");
		return;
	}
	const dstChainSelector = dstNetwork.chainSelector;

	log(
		`Sending tokens from ${srcChain} (${srcChainSelector}) to ${dstChain} (${dstChainSelector})`,
		"sendToken",
		srcChain,
	);

	const bridgeAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChain)}`);
	if (!bridgeAddress) {
		err(`Bridge address not found for ${srcChain}`, "sendToken");
	}

	const usdcAddress = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(srcChain)}`);
	if (!usdcAddress) {
		err(`USDC address not found for ${srcChain}`, "sendToken");
	}

	const dstBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain)}`,
	);
	if (!dstBridgeAddress) {
		err(`Destination bridge address not found for ${dstChain}`, "sendToken");
	}

	if (!bridgeAddress || !usdcAddress || !dstBridgeAddress) {
		return;
	}

	// Determine if we need to approve to pool or bridge
	const isEthereumChain = srcChain.startsWith("ethereum");
	let approvalTarget: string;

	// Determine which contract ABI to use based on chain type
	let bridgeAbi: any;

	if (isEthereumChain) {
		// For Ethereum chains, approve to the pool
		const poolAddress = getEnvVar(
			`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChain)}_${getNetworkEnvKey(dstChain)}` as any,
		);
		if (!poolAddress) return;

		approvalTarget = poolAddress;
		log(`Using pool address for approval: ${poolAddress}`, "sendToken", srcChain);

		const l1BridgeArtifact = await import(
			"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
		);
		bridgeAbi = l1BridgeArtifact.abi;
	} else {
		// For non-Ethereum chains, approve to the bridge
		approvalTarget = bridgeAddress;
		log(`Using bridge address for approval: ${bridgeAddress}`, "sendToken", srcChain);

		const l2BridgeArtifact = await import(
			"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
		);
		bridgeAbi = l2BridgeArtifact.abi;
	}

	const { abi: usdcAbi } = await import(
		"../../artifacts/contracts/usdc/v2/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcNetwork, viemAccount);

	const amountInWei = parseUnits(amount, 6);

	try {
		log("Getting message fee...", "sendToken", srcChain);

		const messageFee = await publicClient.readContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "getBridgeNativeFee",
			args: [
				dstChainSelector,
				dstBridgeAddress as `0x${string}`,
				BigInt(0), // dstGasLimit (not needed for simple transfer)
			],
		});

		log(
			`Message fee: ${formatEther(messageFee)} ETH (${messageFee} wei)`,
			"sendToken",
			srcChain,
		);

		// Approve USDC for bridge contract or pool
		const approvalTargetName = isEthereumChain ? "pool" : "bridge";
		log(`Approving ${amount} USDC to ${approvalTargetName}...`, "sendToken", srcChain);
		const approveTxHash = await walletClient.writeContract({
			address: usdcAddress as `0x${string}`,
			abi: usdcAbi,
			functionName: "approve",
			account: viemAccount,
			args: [approvalTarget, amountInWei],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcNetwork),
			hash: approveTxHash,
		});

		log(`Approval successful: ${approveTxHash}`, "sendToken", srcChain);

		// Send token - prepare arguments based on contract type
		log(
			`Sending ${amount} USDC to ${dstChain} (dstBridge: ${dstBridgeAddress})...`,
			"sendToken",
			srcChain,
		);

		const tokenReceiver = receiver ? receiver : viemAccount.address;

		let sendTokenArgs: any[];
		if (isEthereumChain) {
			// L1 contract: sendToken(tokenReceiver, tokenAmount, dstChainSelector, isTokenReceiverContract, dstGasLimit, dstCallData)
			sendTokenArgs = [
				tokenReceiver, // tokenReceiver
				amountInWei, // tokenAmount
				dstChainSelector, // dstChainSelector
				BigInt(0), // dstGasLimit (not needed for simple transfer)
				"0x", // dstCallData (empty for simple transfer)
			];
		} else {
			// L2 contract: sendToken(tokenReceiver, tokenAmount)
			sendTokenArgs = [
				tokenReceiver, // tokenReceiver
				amountInWei, // tokenAmount
				BigInt(0), // dstGasLimit (not needed for simple transfer)
				"0x", // dstCallData (empty for simple transfer)
			];
		}

		const sendTxHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "sendToken",
			account: viemAccount,
			args: sendTokenArgs,
			value: messageFee,
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcNetwork),
			hash: sendTxHash,
		});

		log(`🎉 Token transfer initiated! Transaction hash: ${sendTxHash}`, "sendToken", srcChain);

		try {
			let messageId: string | null = null;

			for (const receiptLog of receipt.logs) {
				try {
					const decoded = decodeEventLog({
						abi: bridgeAbi,
						data: receiptLog.data,
						topics: receiptLog.topics,
					});

					if (decoded.eventName === "TokenSent") {
						messageId = (decoded.args as any).messageId;
						break;
					}
				} catch (decodeError) {
					continue;
				}
			}

			if (messageId) {
				log(`📡 MessageId: ${messageId}`, "sendToken", srcChain);
				log(`🔄 Starting cross-chain monitoring...`, "sendToken", srcChain);

				await monitorBridgeDelivered(messageId, dstChain);
			} else {
				log(`⚠️ TokenSent event not found in transaction receipt`, "sendToken", srcChain);
			}
		} catch (parseError) {
			log(
				`⚠️ Could not parse events from transaction receipt: ${parseError}`,
				"sendToken",
				srcChain,
			);
		}
	} catch (error) {
		err(`Failed to send tokens: ${error}`, "sendToken", srcChain);
		throw error;
	}
}
