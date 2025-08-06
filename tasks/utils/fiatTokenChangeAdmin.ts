import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function fiatTokenChangeAdmin(
	hre: HardhatRuntimeEnvironment,
	admin: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const adminUpgradeableProxyArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/AdminUpgradeabilityProxy.sol/AdminUpgradeabilityProxy.json",
	);

	const adminUpgradableProxyArtifact = JSON.parse(
		fs.readFileSync(adminUpgradeableProxyArtifactPath, "utf8"),
	);

	const fiatTokenProxyAdminAddress = getEnvVar(
		`FIAT_TOKEN_PROXY_ADMIN_${getNetworkEnvKey(chainName)}`,
	);
	if (!fiatTokenProxyAdminAddress) return;

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log("Executing change admin of FiatToken...", "fiatTokenChangeAdmin", chainName);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAdminAddress as `0x${string}`,
			abi: adminUpgradableProxyArtifact.abi,
			functionName: "changeAdmin",
			account: viemAccount,
			args: [admin],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: configTxHash,
		});

		log(
			`ChangeAdmin completed: ${configReceipt.transactionHash}`,
			"fiatTokenChangeAdmin",
			chainName,
		);
	} catch (error) {
		err(`Failed change admin of FiatToken: ${error}`, "fiatTokenChangeAdmin", chainName);
	}
}
