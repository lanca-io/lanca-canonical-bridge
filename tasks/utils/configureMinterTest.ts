import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

/// For testing purposes, we need to configure the minter to the deployer account
/// This is only for testnet networks and mock USDC
export async function configureMinterTest(hre: HardhatRuntimeEnvironment): Promise<void> {
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
	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	const minterAllowedAmount = 100000e6;

	try {
		log("Executing configuration of FiatToken...", "configureFiatToken", chainName);
		log(
			`Setting minter to ${walletClient.account?.address} with minterAllowedAmount: ${minterAllowedAmount}`,
			"configureFiatToken",
			chainName,
		);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "configureMinter",
			account: viemAccount,
			args: [walletClient.account?.address, minterAllowedAmount],
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
