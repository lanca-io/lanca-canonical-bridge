import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaPoolProxyImplementation(
	srcChainName: string,
	dstChainName: string,
	shouldPause: boolean = false,
): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/Proxy/LCBProxyAdmin.sol/LCBProxyAdmin.json"
	);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(
		srcChain,
		viemAccount,
	);

	const lcBridgeProxy = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!lcBridgeProxy) {
		err(
			`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)} not found.`,
			"upgradeLancaPoolProxy",
			srcChainName,
		);
	}

	const proxyAdmin = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!proxyAdmin) {
		err(
			`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)} not found.`,
			"upgradeLancaPoolProxy",
			srcChainName,
		);
	}

	let newImplementation: string | undefined;
	let implementationDescription: string;

	if (shouldPause) {
		newImplementation = getEnvVar(`CONCERO_PAUSE_${getNetworkEnvKey(srcChainName)}` as any);
		implementationDescription = "pause implementation";
	} else {
		newImplementation = getEnvVar(
			`LC_BRIDGE_POOL_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}` as any,
		);
		implementationDescription = "pool implementation";
	}

	if (!newImplementation) {
		err(`${implementationDescription} not found.`, "upgradeLancaPoolProxy", srcChainName);
	}

	if (!newImplementation || !proxyAdmin || !lcBridgeProxy) {
		return;
	}

	log(
		`Upgrading pool proxy to ${implementationDescription} ${newImplementation}`,
		"upgradeLancaPoolProxy",
		srcChainName,
	);

	const txHash = await walletClient.writeContract({
		address: proxyAdmin,
		abi: proxyAdminAbi,
		functionName: "upgradeAndCall",
		account: viemAccount,
		args: [lcBridgeProxy, newImplementation, "0x"],
		chain: viemChain,
	});

	const receipt = await publicClient.waitForTransactionReceipt({
		...getViemReceiptConfig(srcChain),
		hash: txHash,
	});

	log(
		`Upgraded pool: ${lcBridgeProxy} (${dstChainName} -> ${srcChainName}) to impl: ${newImplementation}. Hash: ${receipt.transactionHash}`,
		`upgradeLancaPoolProxy`,
		srcChainName,
	);
}
