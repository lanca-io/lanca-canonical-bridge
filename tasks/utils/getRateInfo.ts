import { ConceroNetwork, getNetworkEnvKey } from "@concero/contract-utils";
import { formatUnits } from "viem";

import { conceroNetworks } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

interface RateInfo {
	availableVolume: string;
	maxAmount: string;
	refillSpeed: string;
	lastUpdate: number;
	isActive: boolean;
}

interface RateLimitInfo {
	outbound: RateInfo;
	inbound: RateInfo;
	srcChain: string;
	dstChain: string;
	srcChainSelector: string;
	dstChainSelector: string;
}

/**
 * Get rate limit information for src -> dst bridge
 * @param srcChainName - The name of the source chain
 * @param dstChainName - The name of the destination chain (optional, defaults to Ethereum)
 * @returns Rate limit information for both inbound and outbound directions
 */
export async function getRateInfo(
	srcChainName: string,
	dstChainName?: string,
): Promise<RateLimitInfo> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const isL1Bridge = !!dstChainName;

	let dstChain: ConceroNetwork;
	if (isL1Bridge) {
		// Get rate info for L1 bridge
		dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];
		if (!dstChain) {
			err(`Destination network ${dstChainName} not found`, "getRateInfo", srcChain.name);
			return {} as RateLimitInfo;
		}
	} else {
		// Default dst chain is Ethereum
		dstChain =
			networkType === "testnet" ? conceroNetworks.ethereumSepolia : conceroNetworks.ethereum;
		if (!dstChain) {
			err(`Default destination network not found`, "getRateInfo", srcChain.name);
			return {} as RateLimitInfo;
		}
	}

	if (srcChain.name === dstChain.name) {
		err(`Source and destination chains cannot be the same`, "getRateInfo", srcChain.name);
		return {} as RateLimitInfo;
	}

	const contractAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChain.name)}`,
	);

	if (!contractAddress) {
		err(`Contract address not found for ${srcChain.name}`, "getRateInfo", srcChain.name);
		return {} as RateLimitInfo;
	}

	const { abi: bridgeAbi } = isL1Bridge
		? await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
			)
		: await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
			);

	const viemAccount = getViemAccount(networkType, "rateLimitAdmin");
	const { publicClient } = getFallbackClients(srcChain, viemAccount);

	log(
		`Getting rate info for ${isL1Bridge ? "L1" : "L2"} bridge on ${srcChain.name} -> ${dstChain.name}`,
		"getRateInfo",
		srcChain.name,
	);

	try {
		// Get outbound rate info
		const [outAvailableVolume, outMaxAmount, outRefillSpeed, outLastUpdate, outIsActive] =
			(await publicClient.readContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "getRateInfo",
				args: [dstChain.chainSelector, true],
			})) as [bigint, bigint, bigint, number, boolean];

		// Get inbound rate info
		const [inAvailableVolume, inMaxAmount, inRefillSpeed, inLastUpdate, inIsActive] =
			(await publicClient.readContract({
				address: contractAddress as `0x${string}`,
				abi: bridgeAbi,
				functionName: "getRateInfo",
				args: [dstChain.chainSelector, false],
			})) as [bigint, bigint, bigint, number, boolean];

		const rateInfo: RateLimitInfo = {
			srcChain: srcChain.name,
			dstChain: dstChain.name,
			srcChainSelector: srcChain.chainSelector.toString(),
			dstChainSelector: dstChain.chainSelector.toString(),
			outbound: {
				availableVolume: formatUnits(outAvailableVolume, 6),
				maxAmount: formatUnits(outMaxAmount, 6),
				refillSpeed: formatUnits(outRefillSpeed, 6),
				lastUpdate: outLastUpdate,
				isActive: outIsActive,
			},
			inbound: {
				availableVolume: formatUnits(inAvailableVolume, 6),
				maxAmount: formatUnits(inMaxAmount, 6),
				refillSpeed: formatUnits(inRefillSpeed, 6),
				lastUpdate: inLastUpdate,
				isActive: inIsActive,
			},
		};

		log(
			`Rate info retrieved successfully for ${srcChain.name} -> ${dstChain.name}`,
			"getRateInfo",
			srcChain.name,
		);

		return rateInfo;
	} catch (error) {
		err(`Failed to get rate info: ${error}`, "getRateInfo", srcChain.name);
		return {} as RateLimitInfo;
	}
}
