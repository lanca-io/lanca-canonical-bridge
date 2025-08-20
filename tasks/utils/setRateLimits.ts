import { ConceroNetwork, getNetworkEnvKey } from "@concero/contract-utils";
import { parseUnits } from "viem";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { defaultRateLimits } from "../../constants/deploymentVariables";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";
import { getRateInfo } from "./getRateInfo";

/**
 * Set rate limits for src -> dst bridge
 * @param srcChainName - The name of the source chain
 * @param dstChainName - The name of the destination chain
 * @param outMax - The maximum amount of USDC that can be sent per second (without decimals)
 * @param outRefill - The amount of USDC that is refilled per second (without decimals)
 * @param inMax - The maximum amount of USDC that can be received per second (without decimals)
 * @param inRefill - The amount of USDC that is refilled per second (without decimals)
 *
 * @dev If this is the first setup and no parameters are passed, default values from config are used.
 * After initialization, you can change one or more parameters by passing them as arguments.
 * If dstChainName is passed, values will be set on L1 for that chain, otherwise default dstChain is Ethereum.
 * Before setting, current rate limit values are checked, if they match the passed parameters, the transaction is not sent.
 */
export async function setRateLimits(
	srcChainName: string,
	dstChainName?: string,
	outMax?: string,
	outRefill?: string,
	inMax?: string,
	inRefill?: string,
): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type: networkType } = srcChain;

	const isL1Bridge = !!dstChainName;

	let dstChain: ConceroNetwork;
	if (isL1Bridge) {
		// Set rate limits on L1 bridge
		dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];
		if (!dstChain) {
			err(`Destination network ${dstChainName} not found`, "setRateLimits", srcChainName);
			return;
		}
	} else {
		// Default dst chain is Ethereum
		dstChain =
			networkType === "testnet" ? conceroNetworks.ethereumSepolia : conceroNetworks.ethereum;
		if (!dstChain) {
			err(`Destination network ${dstChainName} not found`, "setRateLimits", srcChainName);
			return;
		}
	}

	if (srcChain.name === dstChain.name) {
		err(
			`You need to specify a destination chain name for rate limits`,
			"setRateLimits",
			srcChainName,
		);
		return;
	}

	const contractAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);

	if (!contractAddress) {
		err(`Contract address not found for ${srcChainName}`, "setRateLimits", srcChainName);
		return;
	}

	const { abi: bridgeAbi } = isL1Bridge
		? await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
			)
		: await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
			);

	const viemAccount = getViemAccount(networkType, "rateLimitAdmin");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	// Get current rate info using the new utility
	const currentRateInfo = await getRateInfo(srcChainName, dstChainName);
	if (!currentRateInfo.srcChainSelector) {
		err(`Failed to get rate info`, "setRateLimits", srcChainName);
		return;
	}

	// If rate limits are not provided, use current rate limits
	// If current rate limits are not set, use default rate limits
	const rateLimits = {
		outMax: outMax || Number(currentRateInfo.outbound.maxAmount) || defaultRateLimits.outMax,
		outRefill: outRefill || Number(currentRateInfo.outbound.refillSpeed) || defaultRateLimits.outRefill,
		inMax: inMax || Number(currentRateInfo.inbound.maxAmount) || defaultRateLimits.inMax,
		inRefill: inRefill || Number(currentRateInfo.inbound.refillSpeed) || defaultRateLimits.inRefill,
	};

	try {
		log(
			`Setting rate limits for ${isL1Bridge ? "L1" : "L2"} bridge on ${srcChainName} -> ${dstChain?.name}`,
			"setRateLimits",
			srcChainName,
		);

		// Set rate limits if parameters provided
		// Convert from USDC to wei (6 decimals)
		const outMaxWei = parseUnits(rateLimits.outMax.toString(), 6);
		const outRefillWei = parseUnits(rateLimits.outRefill.toString(), 6);
		const inMaxWei = parseUnits(rateLimits.inMax.toString(), 6);
		const inRefillWei = parseUnits(rateLimits.inRefill.toString(), 6);

		const currentOutMaxWei = parseUnits(currentRateInfo.outbound.maxAmount, 6);
		const currentOutRefillWei = parseUnits(currentRateInfo.outbound.refillSpeed, 6);
		const currentInMaxWei = parseUnits(currentRateInfo.inbound.maxAmount, 6);
		const currentInRefillWei = parseUnits(currentRateInfo.inbound.refillSpeed, 6);

		const outboundNeedsUpdate =
			currentOutMaxWei !== outMaxWei || currentOutRefillWei !== outRefillWei;

		if (outboundNeedsUpdate) {
			const outboundArgs = [dstChain.chainSelector, outMaxWei, outRefillWei, true];

			log(
				`Setting outbound rate limit: maxAmount=${rateLimits.outMax} USDC, refillSpeed=${rateLimits.outRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChain.name} (${dstChain.chainSelector})` : ""}`,
				"setRateLimits",
				srcChainName,
			);

			const outboundTxHash = await walletClient.writeContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "setRateLimit",
				account: viemAccount,
				args: outboundArgs,
				chain: viemChain,
			});

			const outboundReceipt = await publicClient.waitForTransactionReceipt({
				...getViemReceiptConfig(srcChain),
				hash: outboundTxHash,
			});

			log(
				`Outbound rate limit set successfully! Transaction: ${outboundReceipt.transactionHash}`,
				"setRateLimits",
				srcChainName,
			);
		} else {
			log(
				`Outbound rate limits are already set: (maxAmount=${rateLimits.outMax} USDC, refillSpeed=${rateLimits.outRefill} USDC/sec). Skipping transaction.`,
				"setRateLimits",
				srcChainName,
			);
		}

		const inboundNeedsUpdate =
			currentInMaxWei !== inMaxWei || currentInRefillWei !== inRefillWei;

		if (inboundNeedsUpdate) {
			const inboundArgs = [dstChain.chainSelector, inMaxWei, inRefillWei, false];

			log(
				`Setting inbound rate limit: maxAmount=${rateLimits.inMax} USDC, refillSpeed=${rateLimits.inRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChain.name} (${dstChain.chainSelector})` : ""}`,
				"setRateLimits",
				srcChainName,
			);

			const inboundTxHash = await walletClient.writeContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "setRateLimit",
				account: viemAccount,
				args: inboundArgs,
				chain: viemChain,
			});

			const inboundReceipt = await publicClient.waitForTransactionReceipt({
				...getViemReceiptConfig(srcChain),
				hash: inboundTxHash,
			});

			log(
				`Inbound rate limit set successfully! Transaction: ${inboundReceipt.transactionHash}`,
				"setRateLimits",
				srcChainName,
			);
		} else {
			log(
				`Inbound rate limits are already set: (maxAmount=${rateLimits.inMax} USDC, refillSpeed=${rateLimits.inRefill} USDC/sec). Skipping transaction.`,
				"setRateLimits",
				srcChainName,
			);
		}

		if (!outboundNeedsUpdate && !inboundNeedsUpdate) {
			log(
				`All rate limits are already set. No transactions sent.`,
				"setRateLimits",
				srcChainName,
			);
		}
	} catch (error) {
		err(`Failed to set rate limits: ${error}`, "setRateLimits", srcChainName);
		throw error;
	}
}
