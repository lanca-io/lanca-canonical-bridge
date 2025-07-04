import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaPoolProxyImplementation(
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	shouldPause: boolean = false,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/Proxy/ProxyAdmin.sol/ProxyAdmin.json"
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

	let newImplementation: string | undefined;
	let implementationDescription: string;

	if (shouldPause) {
		newImplementation = getEnvVar(`CONCERO_PAUSE_${getNetworkEnvKey(chainName)}` as any);
		implementationDescription = "pause implementation";
	} else {
		newImplementation = getEnvVar(
			`LC_BRIDGE_POOL_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}` as any,
		);
		implementationDescription = "pool implementation";
	}

	if (!newImplementation) return;

	log(
		`Upgrading pool proxy to ${implementationDescription} ${newImplementation}`,
		"upgradeLancaPoolProxy",
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
		`Upgraded pool: ${lcBridgeProxy} (${dstChainName} -> ${chainName}) to impl: ${newImplementation}. Hash: ${txHash}`,
		`upgradeLancaPoolProxy`,
		chainName,
	);
}
