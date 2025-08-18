import { ConceroNetwork, getNetworkEnvKey } from "@concero/contract-utils";
import { parseUnits } from "viem";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { defaultRateLimits } from "../../constants/deploymentVariables";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

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
			err(`Destination network ${dstChainName} not found`, "setRateLimits", srcChain.name);
			return;
		}
	} else {
		// Default dst chain is Ethereum
		dstChain =
			networkType === "testnet" ? conceroNetworks.ethereumSepolia : conceroNetworks.ethereum;
		if (!dstChain) {
			err(`Destination network ${dstChainName} not found`, "setRateLimits", srcChain.name);
			return;
		}
	}

	const contractAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChain.name)}`,
	);

	if (!contractAddress) return;

	const { abi: bridgeAbi } = isL1Bridge
		? await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
			)
		: await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
			);

	const viemAccount = getViemAccount(networkType, "rateLimitAdmin");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const rateLimits = {
		outMax: outMax || defaultRateLimits.outMax,
		outRefill: outRefill || defaultRateLimits.outRefill,
		inMax: inMax || defaultRateLimits.inMax,
		inRefill: inRefill || defaultRateLimits.inRefill,
	};

	try {
		log(
			`Setting rate limits for ${isL1Bridge ? "L1" : "L2"} bridge on ${srcChain.name} -> ${dstChain?.name}`,
			"setRateLimits",
			srcChain.name,
		);

		// Set outbound rate limit if parameters provided
		// Convert from USDC to wei (6 decimals)
		const outMaxWei = parseUnits(rateLimits.outMax, 6);
		const outRefillWei = parseUnits(rateLimits.outRefill, 6);

		const outboundArgs = isL1Bridge
			? [dstChain.chainSelector, outMaxWei, outRefillWei, true]
			: [dstChain.chainSelector, outMaxWei, outRefillWei, true];

		log(
			`Setting outbound rate limit: maxAmount=${rateLimits.outMax} USDC, refillSpeed=${rateLimits.outRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChain.name} (${dstChain.chainSelector})` : ""}`,
			"setRateLimits",
			srcChain.name,
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
			`Outbound rate limit set successfully! Transaction: ${outboundTxHash}`,
			"setRateLimits",
			srcChain.name,
		);

		// Convert from USDC to wei (6 decimals)
		const inMaxWei = parseUnits(rateLimits.inMax, 6);
		const inRefillWei = parseUnits(rateLimits.inRefill, 6);

		const inboundArgs = isL1Bridge
			? [dstChain.chainSelector, inMaxWei, inRefillWei, false]
			: [dstChain.chainSelector, inMaxWei, inRefillWei, false];

		log(
			`Setting inbound rate limit: maxAmount=${rateLimits.inMax} USDC, refillSpeed=${rateLimits.inRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChain.name} (${dstChain.chainSelector})` : ""}`,
			"setRateLimits",
			srcChain.name,
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
			`Inbound rate limit set successfully! Transaction: ${inboundTxHash}`,
			"setRateLimits",
			srcChain.name,
		);

		if (!outMax && !inMax) {
			log(
				"No rate limits to set. Please provide at least one set of parameters.",
				"setRateLimits",
				srcChain.name,
			);
		}
	} catch (error) {
		err(`Failed to set rate limits: ${error}`, "setRateLimits", srcChain.name);
		throw error;
	}
}
