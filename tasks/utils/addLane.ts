import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addLane(
	hre: HardhatRuntimeEnvironment,
	targetChainSelector: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const bridgeAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`);
	if (!bridgeAddress) return;

	const targetNetworkName = Object.keys(conceroNetworks).find(
		name => conceroNetworks[name].chainSelector.toString() === targetChainSelector,
	);

	if (!targetNetworkName) {
		err(
			`Target network not found for chain selector ${targetChainSelector}`,
			"addLane",
			chainName,
		);
		return;
	}

	const laneAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(targetNetworkName)}`,
	);
	if (!laneAddress) return;

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log(
			`Adding lane ${laneAddress} to Bridge for chain ${targetChainSelector}`,
			"addLane",
			chainName,
		);

		const txHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "addLanes",
			account: viemAccount,
			args: [[BigInt(targetChainSelector)], [laneAddress]],
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
