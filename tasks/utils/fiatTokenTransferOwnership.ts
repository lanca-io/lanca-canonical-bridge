import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function fiatTokenTransferOwnership(
	srcChainName: string,
	owner: string,
): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const fiatTokenArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	);
	const fiatTokenArtifact = JSON.parse(fs.readFileSync(fiatTokenArtifactPath, "utf8"));

	const fiatTokenProxyAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChainName)}`);
	if (!fiatTokenProxyAddress) return;

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	try {
		log(
			"Executing transfer ownership of FiatToken...",
			"fiatTokenTransferOwnership",
			srcChainName,
		);
		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "transferOwnership",
			account: viemAccount,
			args: [owner],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: configTxHash,
		});

		log(
			`TransferOwnership completed: ${configReceipt.transactionHash}`,
			"fiatTokenTransferOwnership",
			srcChainName,
		);
	} catch (error) {
		err(
			`Failed transfer ownership of FiatToken: ${error}`,
			"fiatTokenTransferOwnership",
			srcChainName,
		);
	}
}
