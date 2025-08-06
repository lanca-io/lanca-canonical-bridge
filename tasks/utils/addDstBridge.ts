import { getNetworkEnvKey } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function addDstBridge(
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<void> {
	const { name: chainName } = hre.network;
	const { viemChain, type } = conceroNetworks[chainName];

	const dstChain = conceroNetworks[dstChainName];

	const bridgeAddress = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(chainName)}`);
	if (!bridgeAddress) return;

	const dstBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!dstBridgeAddress) return;

	const { abi: bridgeAbi } = await import(
		"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { walletClient, publicClient } = getFallbackClients(
		conceroNetworks[chainName],
		viemAccount,
	);

	try {
		log(
			`Adding destination bridge ${dstBridgeAddress} for chain ${dstChainName}`,
			"addDstBridge",
			chainName,
		);

		const txHash = await walletClient.writeContract({
			address: bridgeAddress as `0x${string}`,
			abi: bridgeAbi,
			functionName: "addDstBridges",
			account: viemAccount,
			args: [[dstChain.chainSelector], [dstBridgeAddress]],
			chain: viemChain,
		});

		const receipt = await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[chainName]),
			hash: txHash,
		});

		log(
			`Destination bridge successfully added! Transaction: ${txHash}`,
			"addDstBridge",
			chainName,
		);
	} catch (error) {
		err(`Failed to add destination bridge: ${error}`, "addDstBridge", chainName);
		throw error;
	}
}
