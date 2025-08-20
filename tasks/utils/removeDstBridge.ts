import { getNetworkEnvKey } from "@concero/contract-utils";

import { ADDRESS_ZERO, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function removeDstBridge(dstChainName: string): Promise<void> {
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
		return;
	}

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(networkType, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	try {
		const currentDstBridgeAddress = await publicClient.readContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "getBridgeAddress",
			args: [dstChain.chainSelector],
		});

		if (
			currentDstBridgeAddress &&
			currentDstBridgeAddress.toString().toLowerCase() === ADDRESS_ZERO.toLowerCase()
		) {
			err(
				`Destination bridge not found for chain ${dstChainName}`,
				"removeDstBridge",
				srcChainName,
			);
			return;
		}

		log(
			`Removing destination bridge for chain ${dstChainName} (${dstChain.chainSelector})`,
			"removeDstBridge",
			srcChainName,
		);

		const txHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "removeDstBridges",
			account: viemAccount,
			args: [[dstChain.chainSelector]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: txHash,
		});

		log(
			`Destination bridge successfully removed! Transaction: ${receipt.transactionHash}`,
			"removeDstBridge",
			srcChainName,
		);
	} catch (error) {
		err(`Failed to remove destination bridge: ${error}`, "removeDstBridge", srcChainName);
		throw error;
	}
}
