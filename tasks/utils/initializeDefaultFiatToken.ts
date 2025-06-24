import fs from "fs";
import path from "path";

import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function initializeDefaultFiatToken(hre: HardhatRuntimeEnvironment): Promise<void> {
    const { name: chainName } = hre.network;
    const { viemChain, type } = conceroNetworks[chainName];

    const fiatTokenArtifactPath = path.resolve(__dirname, "../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json");
    const fiatTokenArtifact = JSON.parse(fs.readFileSync(fiatTokenArtifactPath, "utf8"));

    const viemAccount = getViemAccount(type, "deployer");
    const { walletClient, publicClient } = getFallbackClients(conceroNetworks[chainName], viemAccount);

    const fiatTokenImplementation = getEnvVar(`FIAT_TOKEN_IMPLEMENTATION_${chainName.toUpperCase()}`);
    if (!fiatTokenImplementation) {
        err(`FIAT_TOKEN_PROXY_${chainName.toUpperCase()} not found in environment variables`, "initializeFiatToken");
        return;
    }

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
            abi: fiatTokenArtifact.abi,
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
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initTxHash,
		});

        const initV2TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2",
			account: viemAccount,
			args: [defaultArgs.tokenName],
			chain: viemChain,
		});

        await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2TxHash,
		});

        const initV2_1TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2_1",
			account: viemAccount,
			args: [defaultArgs.lostAndFoundAddress],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2_1TxHash,
		});

        const initV2_2TxHash = await walletClient.writeContract({
			address: fiatTokenImplementation,
			abi: fiatTokenArtifact.abi,
			functionName: "initializeV2_2",
			account: viemAccount,
			args: [[], defaultArgs.tokenSymbol],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: initV2_2TxHash,
		});

        log("Default initialization completed \n", "initializeDefaultFiatToken", chainName);
    } catch (error) {
        err(`Error initializing USDC Proxy: ${error}`, "initializeFiatToken");
        throw error;
    }
}
