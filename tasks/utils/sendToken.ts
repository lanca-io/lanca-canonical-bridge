import { formatEther, parseUnits } from "viem";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

interface SendTokenParams {
	dstChain: string;
	amount: string;
	gasLimit: string;
}

export async function sendToken(
	hre: HardhatRuntimeEnvironment,
	params: SendTokenParams,
): Promise<void> {
	const { dstChain, amount, gasLimit } = params;
	const { name: srcChain } = hre.network;

	const srcNetwork = conceroNetworks[srcChain];
	const { viemChain, type, chainSelector: srcChainSelector } = srcNetwork;

	const dstNetwork = conceroNetworks[dstChain];
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
	if (!bridgeAddress) return;

	const usdcAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChain)}`);
	if (!usdcAddress) return;

	const laneAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain)}`);
	if (!laneAddress) return;

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
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcNetwork, viemAccount);

	const amountInWei = parseUnits(amount, 6);
	const gasLimitBigInt = BigInt(gasLimit);

	const dstChainData = {
		receiver: laneAddress as `0x${string}`,
		gasLimit: gasLimitBigInt,
	};

	try {
		log("Getting message fee...", "sendToken", srcChain);
		const messageFee = await publicClient.readContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "getMessageFee",
			args: [
				dstChainSelector,
				"0x0000000000000000000000000000000000000000", // feeToken (ETH)
				dstChainData,
			],
		});

		log(
			`Message fee: ${formatEther(messageFee as bigint)} ETH (${messageFee} wei)`,
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
			`Sending ${amount} USDC to ${dstChain} (lane: ${laneAddress})...`,
			"sendToken",
			srcChain,
		);

		let sendTokenArgs: any[];
		if (isEthereumChain) {
			// L1 contract: sendToken(amount, dstChainSelector, feeToken, dstChainData)
			sendTokenArgs = [
				amountInWei,
				dstChainSelector,
				"0x0000000000000000000000000000000000000000", // feeToken
				dstChainData,
			];
		} else {
			// L2 contract: sendToken(amount, feeToken, dstChainData)
			sendTokenArgs = [
				amountInWei,
				"0x0000000000000000000000000000000000000000", // feeToken
				dstChainData,
			];
		}

		const sendTxHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "sendToken",
			account: viemAccount,
			args: sendTokenArgs,
			value: messageFee as bigint,
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcNetwork),
			hash: sendTxHash,
		});

		log(
			`🎉 Token transfer successful! Transaction hash: ${sendTxHash} \n`,
			"sendToken",
			srcChain,
		);
	} catch (error) {
		err(`Failed to send tokens: ${error}`, "sendToken", srcChain);
		throw error;
	}
}
