import { HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { EnvPrefixes, IProxyType } from "../../types/deploymentVariables";
import { err, getEnvAddress, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaProxyImplementation(
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
	shouldPause: boolean,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	let implementationKey: keyof EnvPrefixes;

	if (shouldPause) {
		implementationKey = "pause";
	} else if (proxyType === ProxyEnum.lcBridgeProxy) {
		implementationKey = "lcBridge";
	} else {
		err(`Proxy type ${proxyType} not found`, "upgradeProxyImplementation", chainName);
		return;
	}

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/Proxy/LCBProxyAdmin.sol/LCBProxyAdmin.json"
	);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	const [lcBridgeProxy, lcBridgeProxyAlias] = getEnvAddress(proxyType, chainName);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, chainName);
	const [newImplementation, newImplementationAlias] = getEnvAddress(implementationKey, chainName);

	log(
		`Upgrading ${lcBridgeProxyAlias} to implementation ${newImplementationAlias}`,
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
		`Upgraded via ${proxyAdminAlias}: ${lcBridgeProxyAlias}.implementation -> ${newImplementationAlias}. Gas: ${cumulativeGasUsed}, hash: ${txHash}`,
		`upgradeLancaProxy: ${proxyType}`,
		chainName,
	);
}
