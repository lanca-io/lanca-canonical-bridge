import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function initializeDefaultFiatToken(srcChainName: string): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const { abi: fiatTokenAbi } = await import(
		"../../artifacts/contracts/usdc/v2/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const fiatTokenImplementation = getEnvVar(`USDC_${getNetworkEnvKey(srcChainName)}`);
	if (!fiatTokenImplementation) return;

	const THROWAWAY_ADDRESS = "0x0000000000000000000000000000000000000001";

	const defaultArgs = {
		tokenName: "",
		tokenSymbol: "",
		tokenCurrency: "",
		tokenDecimals: 0,
		masterMinterAddress: THROWAWAY_ADDRESS,
		pauserAddress: THROWAWAY_ADDRESS,
		blacklisterAddress: THROWAWAY_ADDRESS,
		ownerAddress: THROWAWAY_ADDRESS,
		lostAndFoundAddress: THROWAWAY_ADDRESS,
	};

	try {
		const initTxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenAbi,
			functionName: "initialize",
			account: viemAccount,
			args: [
				defaultArgs.tokenName,
				defaultArgs.tokenSymbol,
				defaultArgs.tokenCurrency,
				defaultArgs.tokenDecimals,
				defaultArgs.masterMinterAddress,
				defaultArgs.pauserAddress,
				defaultArgs.blacklisterAddress,
				defaultArgs.ownerAddress,
			],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initTxHash,
		});

		const initV2TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenAbi,
			functionName: "initializeV2",
			account: viemAccount,
			args: [defaultArgs.tokenName],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2TxHash,
		});

		const initV2_1TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenAbi,
			functionName: "initializeV2_1",
			account: viemAccount,
			args: [defaultArgs.lostAndFoundAddress],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2_1TxHash,
		});

		const initV2_2TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenAbi,
			functionName: "initializeV2_2",
			account: viemAccount,
			args: [[], defaultArgs.tokenSymbol],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2_2TxHash,
		});

		log("Default initialization completed \n", "initializeDefaultFiatToken", srcChainName);
	} catch (error) {
		err(`Error initializing USDC Proxy: ${error}`, "initializeDefaultFiatToken", srcChainName);
		throw error;
	}
}
