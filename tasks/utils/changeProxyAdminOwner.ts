import { getNetworkEnvKey } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function changeProxyAdminOwner(
	hre: HardhatRuntimeEnvironment,
	envPrefix: string,
	newOwner: string,
	dstChainName?: string,
): Promise<void> {
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	let envVarName: string;
	if (dstChainName) {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`;
	} else {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}`;
	}

	const proxyAdminAddress = getEnvVar(envVarName);
	if (!proxyAdminAddress) {
		throw new Error(
			`ProxyAdmin address not found. Set ${envVarName} in environment variables.`,
		);
	}

	log(`Changing owner of ProxyAdmin at: ${proxyAdminAddress}`, "changeProxyAdminOwner", name);
	log(`  New owner: ${newOwner}`, "changeProxyAdminOwner", name);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(conceroNetworks[name], viemAccount);

	const proxyAdminABI = [
		{
			inputs: [{ internalType: "address", name: "newOwner", type: "address" }],
			name: "transferOwnership",
			outputs: [],
			stateMutability: "nonpayable",
			type: "function",
		},
	];

	try {
		const txHash = await walletClient.writeContract({
			address: proxyAdminAddress as `0x${string}`,
			abi: proxyAdminABI,
			functionName: "transferOwnership",
			account: viemAccount,
			args: [newOwner as `0x${string}`],
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[name]),
			hash: txHash,
		});

		log(
			`Owner changed successfully. Transaction hash: ${txHash}`,
			"changeProxyAdminOwner",
			name,
		);
	} catch (error) {
		err(`Failed to change owner: ${error}`, "changeProxyAdminOwner", name);
		throw error;
	}
}
