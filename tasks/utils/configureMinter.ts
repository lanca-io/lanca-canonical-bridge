import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { defaultMinterAllowedAmount } from "../../constants/deploymentVariables";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function configureMinter(srcChainName: string, amount?: string): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const fiatTokenProxyAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChain.name)}`);
	if (!fiatTokenProxyAddress) {
		err(`FiatToken address not found`, "configureMinter", srcChainName);
	}

	const { abi: fiatTokenAbi } = await import(
		"../../artifacts/contracts/usdc/v2/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	// viemAccount should be master minter address
	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChain.name)}`,
	);
	if (!lancaCanonicalBridgeAddress) {
		err(`LancaCanonicalBridge address not found`, "configureMinter", srcChainName);
	}

	const minterAllowedAmount = amount ? amount : defaultMinterAllowedAmount;

	try {
		log("Executing configuration of FiatToken...", "configureFiatToken", srcChain.name);
		log(
			`Setting lancaCanonicalBridgeAddress ${lancaCanonicalBridgeAddress} as minter with minterAllowedAmount: ${minterAllowedAmount}`,
			"configureFiatToken",
			srcChain.name,
		);

		const isMinter = await publicClient.readContract({
			address: fiatTokenProxyAddress,
			abi: fiatTokenAbi,
			functionName: "isMinter",
			args: [lancaCanonicalBridgeAddress],
		});

		if (isMinter) {
			log("LancaCanonicalBridge is already a minter", "configureFiatToken", srcChain.name);
		}

		const configTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenAbi,
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
			srcChain.name,
		);
	} catch (error) {
		err(`Failed to configure FiatToken: ${error}`, "configureFiatToken", srcChain.name);
	}
}
