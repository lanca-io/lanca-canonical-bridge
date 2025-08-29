import { ProxyEnum, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { EnvPrefixes, IProxyType } from "../../types/deploymentVariables";
import { err, getEnvAddress, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaProxyImplementation(
	srcChainName: string,
	proxyType: IProxyType,
	shouldPause: boolean,
): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	let implementationKey: keyof EnvPrefixes;

	if (shouldPause) {
		implementationKey = "pause";
	} else if (proxyType === ProxyEnum.lcBridgeProxy) {
		implementationKey = "lcBridge";
	} else {
		err(`Proxy type ${proxyType} not found`, "upgradeProxyImplementation", srcChainName);
		return;
	}

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/Proxy/LCBProxyAdmin.sol/LCBProxyAdmin.json"
	);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const [lcBridgeProxy, lcBridgeProxyAlias] = getEnvAddress(proxyType, srcChainName);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, srcChainName);
	const [newImplementation, newImplementationAlias] = getEnvAddress(
		implementationKey,
		srcChainName,
	);

	log(
		`Upgrading ${lcBridgeProxyAlias} to implementation ${newImplementationAlias}`,
		"upgradeLancaProxy",
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

	const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
		...getViemReceiptConfig(srcChain),
		hash: txHash,
	});

	log(
		`Upgraded via ${proxyAdminAlias}: ${lcBridgeProxyAlias}.implementation -> ${newImplementationAlias}. Gas: ${cumulativeGasUsed}, hash: ${txHash}`,
		`upgradeLancaProxy: ${proxyType}`,
		srcChainName,
	);
}
