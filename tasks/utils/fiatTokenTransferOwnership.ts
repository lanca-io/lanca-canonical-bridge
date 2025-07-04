import fs from "fs";
import path from "path";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function fiatTokenTransferOwnership(hre: HardhatRuntimeEnvironment, owner: string): Promise<void> {
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

	try {
		log("Executing transfer ownership of FiatToken...", "fiatTokenTransferOwnership", chainName);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "transferOwnership",
			account: viemAccount,
			args: [owner],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: configTxHash,
		});

		log(
			`TransferOwnership completed: ${configReceipt.transactionHash}`,
			"fiatTokenTransferOwnership",
			chainName,
		);
	} catch (error) {
		err(`Failed transfer ownership of FiatToken: ${error}`, "fiatTokenTransferOwnership", chainName);
	}
}
