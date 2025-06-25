import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addLane(
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

    const dstChain = conceroNetworks[dstChainName];

	const bridgeAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`);
	if (!bridgeAddress) return;

	const laneAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)}`);
	if (!laneAddress) return;

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log(`Adding lane ${laneAddress} to Bridge for chain ${dstChainName}`, "addLane", chainName);

		const txHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "addLanes",
			account: viemAccount,
			args: [[BigInt(dstChain.chainId)], [laneAddress]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: txHash,
		});

		log(`Lane successfully added! Transaction: ${txHash}`, "addLane", chainName);
	} catch (error) {
		err(`Failed to add lane: ${error}`, "addLane", chainName);
		throw error;
	}
}
