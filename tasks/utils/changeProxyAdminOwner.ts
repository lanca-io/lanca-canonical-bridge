import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function changeProxyAdminOwner(
	networkName: string,
	envPrefix: string,
	newOwner: string,
	dstChainName?: string,
): Promise<void> {
	const chain = conceroNetworks[networkName as keyof typeof conceroNetworks];
	const { type: networkType } = chain;

	let envVarName: string;
	if (dstChainName) {
		envVarName = `${envPrefix}_${getNetworkEnvKey(networkName)}_${getNetworkEnvKey(dstChainName)}`;
	} else {
		envVarName = `${envPrefix}_${getNetworkEnvKey(networkName)}`;
	}

	const proxyAdminAddress = getEnvVar(envVarName);
	if (!proxyAdminAddress) {
		err(
			`ProxyAdmin address not found. Set ${envVarName} in environment variables.`,
			"changeProxyAdminOwner",
			networkName,
		);
		return;
	}

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(chain, viemAccount);

	const { abi: proxyAdminAbi } = await import(
		"../../artifacts/contracts/proxy/LCBProxyAdmin.sol/LCBProxyAdmin.json"
	);

	const owner: string = (await publicClient.readContract({
		address: proxyAdminAddress as `0x${string}`,
		abi: proxyAdminAbi,
		functionName: "owner",
	})) as string;

	log(
		`Changing owner of ProxyAdmin at: ${proxyAdminAddress}`,
		"changeProxyAdminOwner",
		networkName,
	);
	log(` Old owner: ${owner}`, "changeProxyAdminOwner", networkName);
	log(` New owner: ${newOwner}`, "changeProxyAdminOwner", networkName);

	if (owner && owner.toLowerCase() === newOwner.toLowerCase()) {
		err(
			`Owner is already set to the same address`,
			"changeProxyAdminOwner",
			networkName,
		);
		return;
	}

	try {
		const txHash = await walletClient.writeContract({
			address: proxyAdminAddress as `0x${string}`,
			abi: proxyAdminAbi,
			functionName: "transferOwnership",
			account: viemAccount,
			args: [newOwner as `0x${string}`],
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(chain),
			hash: txHash,
		});

		log(
			`Owner changed successfully. Transaction hash: ${receipt.transactionHash}`,
			"changeProxyAdminOwner",
			networkName,
		);
	} catch (error) {
		err(`Failed to change owner: ${error}`, "changeProxyAdminOwner", networkName);
		return;
	}
}
