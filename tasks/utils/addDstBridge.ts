import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addDstBridge(dstChainName: string): Promise<void> {
	const dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];
	const { type: networkType } = dstChain;

	const srcChainName = networkType === "mainnet" ? "ethereum" : "ethereumSepolia";

	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain } = srcChain;

	const bridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);
	if (!bridgeAddress) {
		err(
			`SRC Bridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in .env.deployments.${networkType} variables.`,
			"addDstBridge",
			srcChainName,
		);
	}

	const dstBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!dstBridgeAddress) {
		err(
			`DST Bridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)} in .env.deployments.${networkType} variables.`,
			"addDstBridge",
			dstChainName,
		);
	}

	if (!bridgeAddress || !dstBridgeAddress) {
		return;
	}

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(networkType, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const currentDstBridge = await publicClient.readContract({
		address: bridgeAddress as `0x${string}`,
		abi: bridgeAbi,
		functionName: "getBridgeAddress",
		args: [dstChain.chainSelector],
	});

	if (currentDstBridge) {
		err(
			`Destination bridge already exists for chain ${dstChainName}`,
			"addDstBridge",
			srcChainName,
		);
		return;
	}

	try {
		log(
			`Adding destination bridge ${dstBridgeAddress} for chain ${dstChainName}`,
			"addDstBridge",
			srcChainName,
		);

		const txHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "addDstBridges",
			account: viemAccount,
			args: [[dstChain.chainSelector], [dstBridgeAddress]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: txHash,
		});

		log(
			`Destination bridge successfully added! Transaction: ${receipt.transactionHash}`,
			"addDstBridge",
			srcChainName,
		);
	} catch (error) {
		err(`Failed to add destination bridge: ${error}`, "addDstBridge", srcChainName);
		throw error;
	}
}
