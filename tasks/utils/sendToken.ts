import { parseUnits } from "viem";

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

	log(`Sending tokens from ${srcChain} to ${dstChain}`, "sendToken", srcChain);
	log(`Source chain selector: ${srcChainSelector}`, "sendToken", srcChain);
	log(`Destination chain selector: ${dstChainSelector}`, "sendToken", srcChain);

	const bridgeAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChain)}`);

	if (!bridgeAddress) return;

	const dstBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain)}`,
	);

	if (!dstBridgeAddress) return;

	const usdcAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChain)}`);
	if (!usdcAddress) return;

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
	);

	const { abi: usdcAbi } = await import(
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcNetwork, viemAccount);

	const amountInWei = parseUnits(amount, 6);
	const gasLimitBigInt = BigInt(gasLimit);

	try {
		log("Getting message fee...", "sendToken", srcChain);
		const messageFee = await publicClient.readContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "getMessageFee",
			args: [
				dstChainSelector,
				false, // shouldFinaliseSrc
				"0x0000000000000000000000000000000000000000", // feeToken (ETH)
				{
					receiver: dstBridgeAddress,
					gasLimit: gasLimitBigInt,
				},
			],
		});

		log(`Message fee: ${messageFee} wei`, "sendToken", srcChain);

		// 2. Approve USDC for bridge contract
		log(`Approving ${amount} USDC to bridge...`, "sendToken", srcChain);
		const approveTxHash = await walletClient.writeContract({
			address: usdcAddress as `0x${string}`,
			abi: usdcAbi,
			functionName: "approve",
			account: viemAccount,
			args: [bridgeAddress, amountInWei],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcNetwork),
			hash: approveTxHash,
		});

		log(`Approval successful: ${approveTxHash}`, "sendToken", srcChain);

		// 3. Send token
		log(`Sending ${amount} USDC to ${dstChain}...`, "sendToken", srcChain);
		const sendTxHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "sendToken",
			account: viemAccount,
			args: [dstBridgeAddress, dstChainSelector, amountInWei, gasLimitBigInt],
			value: messageFee as bigint,
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcNetwork),
			hash: sendTxHash,
		});

		log(`🎉 Token transfer successful!`, "sendToken", srcChain);
		log(`Transaction hash: ${sendTxHash}`, "sendToken", srcChain);
		log(`Gas used: ${receipt.cumulativeGasUsed}`, "sendToken", srcChain);
		log(`Message fee paid: ${messageFee} wei`, "sendToken", srcChain);
		log(`Amount sent: ${amount} USDC`, "sendToken", srcChain);
		log(`From: ${srcChain} (${srcChainSelector})`, "sendToken", srcChain);
		log(`To: ${dstChain} (${dstChainSelector})`, "sendToken", srcChain);
	} catch (error) {
		err(`Failed to send tokens: ${error}`, "sendToken", srcChain);
		throw error;
	}
}
