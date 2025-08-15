import { getNetworkEnvKey } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function removeDstPool(
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];
	const dstChain = conceroNetworks[dstChainName];

	const l1BridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`,
	);
	if (!l1BridgeAddress) return;

	const { abi: l1BridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log(
			`Removing pool from L1 Bridge for chain ${dstChainName} (${dstChain.chainId})`,
			"removeDstPool",
			chainName,
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
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: txHash,
		});

		log(`Pool successfully removed! Transaction: ${txHash}`, "removeDstPool", chainName);
	} catch (error) {
		err(`Failed to remove pool: ${error}`, "removeDstPool", chainName);
		throw error;
	}
}
