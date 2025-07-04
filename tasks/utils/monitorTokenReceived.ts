import { decodeEventLog, formatUnits } from "viem";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function monitorTokenReceived(
	messageId: string,
	srcChain: string,
	dstChain: string,
	expectedAmount: string,
	timeoutMs: number = 300000, // 5 minutes default
): Promise<void> {
	const dstNetwork = conceroNetworks[dstChain];
	if (!dstNetwork) {
		err(`Destination network ${dstChain} not found`, "monitorTokenReceived", dstChain);
		return;
	}

	const dstBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain)}`,
	);
	if (!dstBridgeAddress) return;

	// Determine if target network is L1 or L2
	const isL1Chain = dstChain.startsWith("ethereum");

	// Get correct ABI for dst chain
	const { abi: dstBridgeAbi } = isL1Chain
		? await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol/LancaCanonicalBridgeL1.json"
			)
		: await import(
				"../../artifacts/contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol/LancaCanonicalBridge.json"
			);

	const { type } = dstNetwork;
	const viemAccount = getViemAccount(type, "deployer");
	const { publicClient } = getFallbackClients(dstNetwork, viemAccount);

	log(
		`🔍 Monitoring TokenReceived event on ${dstChain} for messageId: ${messageId}`,
		"monitorTokenReceived",
		dstChain,
	);

	const startTime = Date.now();
	const pollInterval = 5000; // Check every 5 seconds

	return new Promise<void>((resolve, reject) => {
		const pollForEvent = async () => {
			try {
				const currentTime = Date.now();

				// Check timeout
				if (currentTime - startTime > timeoutMs) {
					err(
						`❌ Timeout: TokenReceived event not found after ${timeoutMs / 1000} seconds`,
						"monitorTokenReceived",
						dstChain,
					);
					reject(new Error("Timeout waiting for TokenReceived event"));
					return;
				}

				// Get TokenReceived events from recent blocks
				const currentBlock = await publicClient.getBlockNumber();
				const fromBlock = currentBlock - 100n; // Check last 100 blocks

				const events = await publicClient.getLogs({
					address: dstBridgeAddress as `0x${string}`,
					fromBlock,
					toBlock: "latest",
				});

				// Search for event with our messageId
				for (const event of events) {
					try {
						const decoded = decodeEventLog({
							abi: dstBridgeAbi,
							data: event.data,
							topics: event.topics,
						});

						if (
							decoded.eventName === "TokenReceived" &&
							decoded.args &&
							(decoded.args as any).messageId === messageId
						) {
							const args = decoded.args as any;

							const senderAddress = args.sender;

							log(`✅ TokenReceived event found!`, "monitorTokenReceived", dstChain);
							log(
								`   MessageId: ${args.messageId}`,
								"monitorTokenReceived",
								dstChain,
							);
							log(`   Sender: ${senderAddress}`, "monitorTokenReceived", dstChain);
							log(
								`   TokenSender: ${args.tokenSender}`,
								"monitorTokenReceived",
								dstChain,
							);
							log(
								`   Amount: ${args.amount} wei (${formatUnits(args.amount, 6)} USDC)`,
								"monitorTokenReceived",
								dstChain,
							);
							log(
								`   Transaction Hash: ${event.transactionHash}`,
								"monitorTokenReceived",
								dstChain,
							);
							log(
								`   Block Number: ${event.blockNumber}`,
								"monitorTokenReceived",
								dstChain,
							);
							log(
								`🎉 Cross-chain transfer completed successfully!`,
								"monitorTokenReceived",
								dstChain,
							);

							resolve();
							return;
						}
					} catch (decodeError) {
						// Skip logs that don't match our ABI
						continue;
					}
				}

				// If event not found, continue searching
				log(
					`⏳ Waiting for TokenReceived event... (${Math.floor((currentTime - startTime) / 1000)}s elapsed)`,
					"monitorTokenReceived",
					dstChain,
				);
				setTimeout(pollForEvent, pollInterval);
			} catch (error) {
				err(
					`Error monitoring TokenReceived event: ${error}`,
					"monitorTokenReceived",
					dstChain,
				);
				reject(error);
			}
		};

		// Start monitoring
		pollForEvent();
	});
}
