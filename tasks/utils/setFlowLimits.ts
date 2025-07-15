import { formatUnits, parseUnits } from "viem";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function setFlowLimits(
	hre: HardhatRuntimeEnvironment,
	dstChainName?: string,
	outMax?: string,
	outRefill?: string,
	inMax?: string,
	inRefill?: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	// Determine if this is L1 or L2 bridge based on presence of dstChainName
	const isL1Bridge = !!dstChainName;

	// Get destination chain ID if this is L1 bridge
	let dstChainId: bigint | undefined;
	if (isL1Bridge) {
		const dstChain = conceroNetworks[dstChainName!];
		if (!dstChain) {
			err(`Destination network ${dstChainName} not found`, "setFlowLimits", chainName);
			return;
		}
		dstChainId = BigInt(dstChain.chainId);
	}

	// Get the bridge contract address (both L1 and L2 use the same env var)
	const contractAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`,
	);

	if (!contractAddress) return;

	// Get the appropriate ABI
	const { abi: bridgeAbi } = isL1Bridge
		? await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
			)
		: await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
			);

	const viemAccount = getViemAccount(type, "rateAdmin");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log(
			`Setting rate limits for ${isL1Bridge ? "L1" : "L2"} bridge on ${chainName}${isL1Bridge ? ` -> ${dstChainName}` : ""}`,
			"setFlowLimits",
			chainName,
		);

		// Set outbound rate limit if parameters provided
		if (outMax !== undefined && outRefill !== undefined) {
			// Convert from USDC to wei (6 decimals)
			const outMaxWei = parseUnits(outMax, 6);
			const outRefillWei = parseUnits(outRefill, 6);

			const outboundArgs = isL1Bridge
				? [dstChainId!, outMaxWei, outRefillWei]
				: [outMaxWei, outRefillWei];

			log(
				`Setting outbound rate limit: maxAmount=${outMax} USDC, refillSpeed=${outRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChainName} (${dstChainId})` : ""}`,
				"setFlowLimits",
				chainName,
			);

			const outboundTxHash = await walletClient.writeContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "setOutboundFlowLimit",
				account: viemAccount,
				args: outboundArgs,
				chain: viemChain,
			});

			const outboundReceipt = await publicClient.waitForTransactionReceipt({
				...getViemReceiptConfig(conceroNetworks[chainName]),
				hash: outboundTxHash,
			});

			log(
				`Outbound rate limit set successfully! Transaction: ${outboundTxHash}`,
				"setFlowLimits",
				chainName,
			);
		}

		// Set inbound rate limit if parameters provided
		if (inMax !== undefined && inRefill !== undefined) {
			// Convert from USDC to wei (6 decimals)
			const inMaxWei = parseUnits(inMax, 6);
			const inRefillWei = parseUnits(inRefill, 6);

			const inboundArgs = isL1Bridge
				? [dstChainId!, inMaxWei, inRefillWei]
				: [inMaxWei, inRefillWei];

			log(
				`Setting inbound rate limit: maxAmount=${inMax} USDC, refillSpeed=${inRefill} USDC/sec${isL1Bridge ? `, dstChain=${dstChainName} (${dstChainId})` : ""}`,
				"setFlowLimits",
				chainName,
			);

			const inboundTxHash = await walletClient.writeContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "setInboundFlowLimit",
				account: viemAccount,
				args: inboundArgs,
				chain: viemChain,
			});

			const inboundReceipt = await publicClient.waitForTransactionReceipt({
				...getViemReceiptConfig(conceroNetworks[chainName]),
				hash: inboundTxHash,
			});

			log(
				`Inbound rate limit set successfully! Transaction: ${inboundTxHash}`,
				"setFlowLimits",
				chainName,
			);
		}

		if (!outMax && !inMax) {
			log(
				"No rate limits to set. Please provide at least one set of parameters.",
				"setFlowLimits",
				chainName,
			);
		}
	} catch (error) {
		err(`Failed to set rate limits: ${error}`, "setFlowLimits", chainName);
		throw error;
	}
}
