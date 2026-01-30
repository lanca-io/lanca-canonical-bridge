import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, fiatTokenV2Abi, getViemReceiptConfig } from "../../constants";
import { defaultMinterAllowedAmount } from "../../constants/deploymentVariables";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function configureMinter(srcChainName: string, amount?: string): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const fiatTokenProxyAddress = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(srcChainName)}`);
	if (!fiatTokenProxyAddress) {
		err(`FiatToken address not found`, "configureMinter", srcChainName);
	}

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LC_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);
	if (!lancaCanonicalBridgeAddress) {
		err(`LancaCanonicalBridge address not found`, "configureMinter", srcChainName);
	}

	const minterAllowedAmount = amount ? amount : defaultMinterAllowedAmount;

	try {
		log("Executing configuration of FiatToken...", "configureFiatToken", srcChainName);
		log(
			`Setting lancaCanonicalBridgeAddress ${lancaCanonicalBridgeAddress} as minter with minterAllowedAmount: ${minterAllowedAmount}`,
			"configureFiatToken",
			srcChainName,
		);

		const isMinter = await publicClient.readContract({
			address: fiatTokenProxyAddress,
			abi: fiatTokenV2Abi,
			functionName: "isMinter",
			args: [lancaCanonicalBridgeAddress],
		});

		if (isMinter) {
			log("LancaCanonicalBridge is already a minter", "configureFiatToken", srcChainName);
			return;
		}

		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenV2Abi,
			functionName: "configureMinter",
			account: viemAccount,
			args: [lancaCanonicalBridgeAddress, minterAllowedAmount],
			chain: viemChain,
		});

		const configReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: configTxHash,
		});

		log(
			`Configuration completed: ${configReceipt.transactionHash}`,
			"configureFiatToken",
			srcChainName,
		);
	} catch (error) {
		err(`Failed to configure FiatToken: ${error}`, "configureFiatToken", srcChainName);
	}
}
