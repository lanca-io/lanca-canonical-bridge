import { getNetworkEnvKey } from "@concero/contract-utils";

import { ADDRESS_ZERO, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function removeDstPool(dstChainName: string): Promise<void> {
	const dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];
	const { type: networkType } = dstChain;

	const srcChainName = networkType === "mainnet" ? "ethereum" : "ethereumSepolia";

	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain } = srcChain;

	const l1BridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);
	if (!l1BridgeAddress) {
		err(
			`SRC Bridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in .env.deployments.${networkType} variables.`,
			"removeDstPool",
			srcChainName,
		);
		return;
	}

	const { abi: l1BridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(networkType, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	try {
		const currentDstPoolAddress = await publicClient.readContract({
			address: l1BridgeAddress as `0x${string}`,
			abi: l1BridgeAbi,
			functionName: "getPool",
			args: [dstChain.chainSelector],
		});

		if (!currentDstPoolAddress) {
			err(
				`Destination pool not found for chain ${dstChainName}`,
				"removeDstPool",
				srcChainName,
			);
			return;
		}

		if (currentDstPoolAddress.toString().toLowerCase() === ADDRESS_ZERO.toLowerCase()) {
			err(
				`Destination pool not found for chain ${dstChainName}`,
				"removeDstPool",
				srcChainName,
			);
			return;
		}

		log(
			`Removing pool from L1 Bridge for chain ${dstChainName} (${dstChain.chainId})`,
			"removeDstPool",
			srcChainName,
		);

		const txHash = await walletClient.writeContract({
			address: l1BridgeAddress as `0x${string}`,
			abi: l1BridgeAbi,
			functionName: "removePools",
			account: viemAccount,
			args: [[BigInt(dstChain.chainId)]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: txHash,
		});

		log(
			`Pool successfully removed! Transaction: ${receipt.transactionHash}`,
			"removeDstPool",
			srcChainName,
		);
	} catch (error) {
		err(`Failed to remove pool: ${error}`, "removeDstPool", srcChainName);
		throw error;
	}
}
