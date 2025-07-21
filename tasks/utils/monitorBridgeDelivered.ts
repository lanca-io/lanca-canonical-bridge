import { decodeEventLog, formatUnits } from "viem";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

export async function monitorBridgeDelivered(
	messageId: string,
	srcChain: string,
	dstChain: string,
	expectedAmount: string,
	timeoutMs: number = 300000, // 5 minutes default
): Promise<void> {
	const dstNetwork = conceroNetworks[dstChain];
	if (!dstNetwork) {
		err(`Destination network ${dstChain} not found`, "monitorBridgeDelivered", dstChain);
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
		`🔍 Monitoring BridgeDelivered event on ${dstChain} for messageId: ${messageId}`,
		"monitorBridgeDelivered",
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
						`❌ Timeout: BridgeDelivered event not found after ${timeoutMs / 1000} seconds`,
						"monitorBridgeDelivered",
						dstChain,
					);
					reject(new Error("Timeout waiting for BridgeDelivered event"));
					return;
				}

				// Get BridgeDelivered events from recent blocks
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
							decoded.eventName === "BridgeDelivered" &&
							decoded.args &&
							(decoded.args as any).messageId === messageId
						) {
							const args = decoded.args as any;

							const senderAddress = args.srcBridge;

							log(
								`✅ BridgeDelivered event found!`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`   MessageId: ${args.messageId}`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(`   Sender: ${senderAddress}`, "monitorBridgeDelivered", dstChain);
							log(
								`   TokenSender: ${args.tokenSender}`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`   TokenReceiver: ${args.tokenReceiver}`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`   TokenAmount: ${args.tokenAmount} wei (${formatUnits(args.tokenAmount, 6)} USDC)`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`   Transaction Hash: ${event.transactionHash}`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`   Block Number: ${event.blockNumber}`,
								"monitorBridgeDelivered",
								dstChain,
							);
							log(
								`🎉 Cross-chain transfer completed successfully!`,
								"monitorBridgeDelivered",
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
					`⏳ Waiting for BridgeDelivered event... (${Math.floor((currentTime - startTime) / 1000)}s elapsed)`,
					"monitorBridgeDelivered",
					dstChain,
				);
				setTimeout(pollForEvent, pollInterval);
			} catch (error) {
				err(
					`Error monitoring BridgeDelivered event: ${error}`,
					"monitorBridgeDelivered",
					dstChain,
				);
				reject(error);
			}
		};

		// Start monitoring
		pollForEvent();
	});
}
