import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { EnvPrefixes } from "../../types/deploymentVariables";
import { getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaProxyImplementation(
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const dstChain = conceroNetworks[dstChainName];

	let implementationKey: keyof EnvPrefixes;

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/Proxy/LancaCanonicalBridgeProxyAdmin.sol/LancaCanonicalBridgeProxyAdmin.json"
	);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	const lcBridgeProxy = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!lcBridgeProxy) return;

	const proxyAdmin = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!proxyAdmin) return;

	const newImplementation = getEnvVar(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!newImplementation) return;

	log(
		`Upgrading pool proxy to implementation ${newImplementation}`,
		"upgradeLancaProxy",
		chainName,
	);

	const txHash = await walletClient.writeContract({
		address: proxyAdmin,
		abi: proxyAdminAbi,
		functionName: "upgradeAndCall",
		account: viemAccount,
		args: [lcBridgeProxy, newImplementation, "0x"],
		chain: viemChain,
	});

	const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
		...getViemReceiptConfig(conceroNetworks[chainName]),
		hash: txHash,
	});

	log(
		`Upgraded via lcBridgeProxyAdmin: ${newImplementation}`,
		`upgradeLancaProxy`,
		chainName,
	);
}
