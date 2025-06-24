import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addPool(
	hre: HardhatRuntimeEnvironment,
	targetChainSelector: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const l1BridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`,
	);
	if (!l1BridgeAddress) return;

	const poolAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_POOL_PROXY_${getNetworkEnvKey(chainName)}`,
	);
	if (!poolAddress) return;

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
			`Adding pool ${poolAddress} to L1 Bridge for chain ${targetChainSelector}`,
			"addPool",
			chainName,
		);

		const txHash = await walletClient.writeContract({
			address: l1BridgeAddress as `0x${string}`,
			abi: l1BridgeAbi,
			functionName: "addPools",
			account: viemAccount,
			args: [[BigInt(targetChainSelector)], [poolAddress]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: txHash,
		});

		log(
			`Pool successfully added! Transaction: ${txHash}, Gas used: ${receipt.cumulativeGasUsed}`,
			"addPool",
			chainName,
		);
	} catch (error) {
		err(`Failed to add pool: ${error}`, "addPool", chainName);
		throw error;
	}
}
