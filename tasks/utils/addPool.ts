import { getNetworkEnvKey } from "@concero/contract-utils";

import { ADDRESS_ZERO, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addPool(dstChainName: string): Promise<void> {
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
			`L1 Bridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in .env.deployments.${networkType} variables.`,
			"addPool",
			srcChainName,
		);
	}

	const poolAddress = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!poolAddress) {
		err(
			`Pool address not found. Set LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)} in .env.deployments.${networkType} variables.`,
			"addPool",
			srcChainName,
		);
	}

	if (!l1BridgeAddress || !poolAddress) {
		return;
	}

	const { abi: l1BridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(networkType, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const currentPool = await publicClient.readContract({
		address: l1BridgeAddress as `0x${string}`,
		abi: l1BridgeAbi,
		functionName: "getPool",
		args: [BigInt(dstChain.chainId)],
	});

	if (currentPool && currentPool.toString() !== ADDRESS_ZERO) {
		err(
			`Pool already exists for chain ${dstChainName} (${dstChain.chainId})`,
			"addPool",
			srcChainName,
		);
		return;
	}

	try {
		log(
			`Adding pool ${poolAddress} to L1 Bridge for chain ${dstChainName} (${dstChain.chainId})`,
			"addPool",
			srcChainName,
		);

		const txHash = await walletClient.writeContract({
			address: l1BridgeAddress as `0x${string}`,
			abi: l1BridgeAbi,
			functionName: "addPools",
			account: viemAccount,
			args: [[BigInt(dstChain.chainId)], [poolAddress]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: txHash,
		});

		log(
			`Pool successfully added! Transaction: ${receipt.transactionHash}`,
			"addPool",
			srcChainName,
		);
	} catch (error) {
		err(`Failed to add pool: ${error}`, "addPool", srcChainName);
		throw error;
	}
}
