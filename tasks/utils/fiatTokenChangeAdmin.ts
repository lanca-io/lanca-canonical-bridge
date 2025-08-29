import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function fiatTokenChangeAdmin(srcChainName: string, admin: string): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const adminUpgradeableProxyArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/AdminUpgradeabilityProxy.sol/AdminUpgradeabilityProxy.json",
	);

	const adminUpgradableProxyArtifact = JSON.parse(
		fs.readFileSync(adminUpgradeableProxyArtifactPath, "utf8"),
	);

	const fiatTokenProxyAdminAddress = getEnvVar(
		`USDC_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}`,
	);
	if (!fiatTokenProxyAdminAddress) return;

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	try {
		log("Executing change admin of FiatToken...", "fiatTokenChangeAdmin", srcChainName);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAdminAddress as `0x${string}`,
			abi: adminUpgradableProxyArtifact.abi,
			functionName: "changeAdmin",
			account: viemAccount,
			args: [admin],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: configTxHash,
		});

		log(
			`ChangeAdmin completed: ${configReceipt.transactionHash}`,
			"fiatTokenChangeAdmin",
			srcChainName,
		);
	} catch (error) {
		err(`Failed change admin of FiatToken: ${error}`, "fiatTokenChangeAdmin", srcChainName);
	}
}
