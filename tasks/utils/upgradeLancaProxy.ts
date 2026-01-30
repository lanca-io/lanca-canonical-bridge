import { HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum, conceroNetworks, getViemReceiptConfig } from "../../constants";
import { EnvPrefixes, IProxyType } from "../../types/deploymentVariables";
import { err, getEnvAddress, getFallbackClients, getViemAccount, log } from "../../utils";

export async function upgradeLancaProxyImplementation(
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
	shouldPause: boolean,
	dstChainName?: string,
): Promise<void> {
	const srcChainName = hre.network.name;
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	let implementationKey: keyof EnvPrefixes;
	let envChainName: string;
	if (shouldPause) {
		implementationKey = "pause";
		envChainName = srcChainName;
	} else if (proxyType === ProxyEnum.lcBridgeProxy) {
		implementationKey = "lcBridge";
		envChainName = srcChainName;
	} else if (proxyType === ProxyEnum.lcBridgePoolProxy) {
		implementationKey = "lcBridgePool";
		envChainName = dstChainName || "";
	} else {
		err(`Proxy type ${proxyType} not found`, "upgradeProxyImplementation", srcChainName);
		return;
	}

	const { abi: proxyAdminAbi } = hre.artifacts.readArtifactSync("ProxyAdmin");

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const [lcBridgeProxy, lcBridgeProxyAlias] = getEnvAddress(proxyType, envChainName);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, envChainName);
	const [newImplementation, newImplementationAlias] = getEnvAddress(
		implementationKey,
		envChainName,
	);

	const txHash = await walletClient.writeContract({
		address: proxyAdmin,
		abi: proxyAdminAbi,
		functionName: "upgradeAndCall",
		account: viemAccount,
		args: [lcBridgeProxy, newImplementation, "0x"],
		chain: viemChain,
	});

	await publicClient.waitForTransactionReceipt({
		...getViemReceiptConfig(srcChain),
		hash: txHash,
	});

	log(
		`Upgraded via ${proxyAdminAlias}: ${lcBridgeProxyAlias}.implementation -> ${newImplementationAlias}, hash: ${txHash}`,
		`upgradeLancaProxy: ${proxyType}`,
		envChainName,
	);
}
