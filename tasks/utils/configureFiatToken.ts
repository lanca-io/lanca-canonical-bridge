import fs from "fs";
import path from "path";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function configureFiatToken(hre: HardhatRuntimeEnvironment): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const fiatTokenArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	);
	const fiatTokenArtifact = JSON.parse(fs.readFileSync(fiatTokenArtifactPath, "utf8"));

	const fiatTokenProxyAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(chainName)}`);
    if (!fiatTokenProxyAddress) return;

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`,
	);
	if (!lancaCanonicalBridgeAddress) return;

	const minterAllowedAmount = 100000e6;

	try {
		log("Executing configuration of FiatToken...", "configureFiatToken", chainName);
		log(
			`Setting lancaCanonicalBridgeAddress to ${lancaCanonicalBridgeAddress} with minterAllowedAmount: ${minterAllowedAmount}`,
			"configureFiatToken",
			chainName,
		);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "configureMinter",
			account: viemAccount,
			args: [lancaCanonicalBridgeAddress, minterAllowedAmount],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: configTxHash,
		});

		log(
			`Configuration completed: ${configReceipt.transactionHash}`,
			"configureFiatToken",
			chainName,
		);
	} catch (error) {
		err(`Failed to configure FiatToken: ${error}`, "configureFiatToken", chainName);
	}
}