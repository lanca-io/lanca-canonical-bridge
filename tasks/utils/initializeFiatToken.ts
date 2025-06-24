import fs from "fs";
import path from "path";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";
import { getNetworkEnvKey } from "@concero/contract-utils";

export async function initializeFiatToken(hre: HardhatRuntimeEnvironment): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const fiatTokenArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	);
	const fiatTokenArtifact = JSON.parse(fs.readFileSync(fiatTokenArtifactPath, "utf8"));

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	const fiatTokenProxy = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(chainName)}`);
	if (!fiatTokenProxy) return;

	const defaultArgs = {
		tokenName: "USD Coin",
		tokenSymbol: "USDC.e",
		tokenCurrency: "USD",
		tokenDecimals: 6,
	};

	const masterMinterAddress = getEnvVar(`FIAT_TOKEN_MASTER_MINTER_ADDRESS`);
	const pauserAddress = getEnvVar(`FIAT_TOKEN_PAUSER_ADDRESS`);
	const blacklisterAddress = getEnvVar(`FIAT_TOKEN_BLACKLISTER_ADDRESS`);
	const ownerAddress = getEnvVar(`FIAT_TOKEN_OWNER_ADDRESS`);
	const lostAndFoundAddress = getEnvVar(`FIAT_TOKEN_LOST_AND_FOUND_ADDRESS`);

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
		log("Executing initialization V1...", "initializeFiatToken", chainName);
		const initTxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenArtifact.abi,
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
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initTxHash,
		});

		// 2. Initialization (V2)
		log("Executing initialization V2...", "initializeFiatToken", chainName);
		const initV2TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2",
			account: viemAccount,
			args: [defaultArgs.tokenName],
			chain: viemChain,
		});

		const initV2Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2TxHash,
		});

		// 3. Initialization V2.1
		log("Executing initialization V2.1...", "initializeFiatToken", chainName);
		const initV2_1TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2_1",
			account: viemAccount,
			args: [lostAndFoundAddress],
			chain: viemChain,
		});

		const initV2_1Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2_1TxHash,
		});

		// 4. Initialization V2.2
		log("Executing initialization V2.2...", "initializeFiatToken", chainName);
		const initV2_2TxHash = await walletClient.writeContract({
			address: fiatTokenProxy as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2_2",
			account: viemAccount,
			args: [[], defaultArgs.tokenSymbol],
			chain: viemChain,
		});

		const initV2_2Receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2_2TxHash,
		});

		log(
			"🎉 Full initialization of USDC Proxy contract completed!",
			"initializeFiatToken",
			chainName,
		);
		log("All initialization steps completed successfully:", "initializeFiatToken", chainName);
		log(`  - V1: ${initTxHash}`, "initializeFiatToken", chainName);
		log(`  - V2: ${initV2TxHash}`, "initializeFiatToken", chainName);
		log(`  - V2.1: ${initV2_1TxHash}`, "initializeFiatToken", chainName);
		log(`  - V2.2: ${initV2_2TxHash}`, "initializeFiatToken", chainName);
	} catch (error) {
		err(`Error initializing USDC Proxy: ${error}`, "initializeFiatToken");
		throw error;
	}
}
