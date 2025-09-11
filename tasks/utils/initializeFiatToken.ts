import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function initializeFiatToken(srcChainName: string): Promise<void> {
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { viemChain, type } = srcChain;

	const { abi: fiatTokenAbi } = await import(
		"../../artifacts/contracts/usdc/v2/FiatTokenV2_2.sol/FiatTokenV2_2.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	const fiatTokenProxy = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(srcChainName)}`);
	if (!fiatTokenProxy) return;

	const defaultArgs = {
		tokenName: "USD Coin",
		tokenSymbol: "USDC.e",
		tokenCurrency: "USD",
		tokenDecimals: 6,
	};

	const masterMinterAddress = getEnvVar(`USDC_MASTER_MINTER_ADDRESS`);
	const pauserAddress = getEnvVar(`USDC_PAUSER_ADDRESS`);
	const blacklisterAddress = getEnvVar(`USDC_BLACKLISTER_ADDRESS`);
	const ownerAddress = getEnvVar(`USDC_OWNER_ADDRESS`);
	const lostAndFoundAddress = getEnvVar(`USDC_LOST_AND_FOUND_ADDRESS`);

	if (
		!masterMinterAddress ||
		!pauserAddress ||
		!blacklisterAddress ||
		!ownerAddress ||
		!lostAndFoundAddress
	) {
		err("Required: fiat token initialization addresses", "initializeFiatToken");
		return;
	}

	try {
		// 1. Main initialization (V1)
		log("Executing initialization V1...", "initializeFiatToken", srcChainName);
		const initTxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenAbi,
			functionName: "initialize",
			account: viemAccount,
			args: [
				defaultArgs.tokenName,
				defaultArgs.tokenSymbol,
				defaultArgs.tokenCurrency,
				defaultArgs.tokenDecimals,
				masterMinterAddress,
				pauserAddress,
				blacklisterAddress,
				ownerAddress,
			],
			chain: viemChain,
		});

		const initReceipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initTxHash,
		});

		// 2. Initialization (V2)
		log("Executing initialization V2...", "initializeFiatToken", srcChainName);
		const initV2TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenAbi,
			functionName: "initializeV2",
			account: viemAccount,
			args: [defaultArgs.tokenName],
			chain: viemChain,
		});

		const initV2Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2TxHash,
		});

		// 3. Initialization V2.1
		log("Executing initialization V2.1...", "initializeFiatToken", srcChainName);
		const initV2_1TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenAbi,
			functionName: "initializeV2_1",
			account: viemAccount,
			args: [lostAndFoundAddress],
			chain: viemChain,
		});

		const initV2_1Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2_1TxHash,
		});

		// 4. Initialization V2.2
		log("Executing initialization V2.2...", "initializeFiatToken", srcChainName);
		const initV2_2TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenAbi,
			functionName: "initializeV2_2",
			account: viemAccount,
			args: [[], defaultArgs.tokenSymbol],
			chain: viemChain,
		});

		const initV2_2Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: initV2_2TxHash,
		});

		log(
			"🎉 Full initialization of USDC Proxy contract completed!",
			"initializeFiatToken",
			srcChainName,
		);
		log(
			"All initialization steps completed successfully:",
			"initializeFiatToken",
			srcChainName,
		);
		log(`  - V1: ${initTxHash}`, "initializeFiatToken", srcChainName);
		log(`  - V2: ${initV2TxHash}`, "initializeFiatToken", srcChainName);
		log(`  - V2.1: ${initV2_1TxHash}`, "initializeFiatToken", srcChainName);
		log(`  - V2.2: ${initV2_2TxHash}`, "initializeFiatToken", srcChainName);
	} catch (error) {
		err(`Error initializing USDC Proxy: ${error}`, "initializeFiatToken");
		throw error;
	}
}
