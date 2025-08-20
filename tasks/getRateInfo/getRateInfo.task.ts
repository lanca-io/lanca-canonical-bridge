import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { getRateInfo } from "../utils";
import { err } from "../../utils";

async function getRateInfoTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	const rateInfo = await getRateInfo(hre.network.name, taskArgs.dstchain);
	if (!rateInfo.srcChainSelector) {
		err(`Failed to get rate info`, "getRateInfoTask", hre.network.name);
		return;
	}

	console.log("\n=== Rate Limit Information ===");
	console.log(`SRC: ${rateInfo.srcChain} (${rateInfo.srcChainSelector})`);
	console.log(`DST: ${rateInfo.dstChain} (${rateInfo.dstChainSelector})`);

	console.log("\n--- Outbound Rate Limits ---");
	console.log(`active: ${rateInfo.outbound.isActive}`);
	console.log(`availableVolume: ${rateInfo.outbound.availableVolume} USDC`);
	console.log(`maxAmount: ${rateInfo.outbound.maxAmount} USDC`);
	console.log(`refillSpeed: ${rateInfo.outbound.refillSpeed} USDC/sec`);
	console.log(`lastUpdate: ${new Date(rateInfo.outbound.lastUpdate * 1000).toISOString()}`);

	console.log("\n--- Inbound Rate Limits ---");
	console.log(`active: ${rateInfo.inbound.isActive}`);
	console.log(`availableVolume: ${rateInfo.inbound.availableVolume} USDC`);
	console.log(`maxAmount: ${rateInfo.inbound.maxAmount} USDC`);
	console.log(`refillSpeed: ${rateInfo.inbound.refillSpeed} USDC/sec`);
	console.log(`lastUpdate: ${new Date(rateInfo.inbound.lastUpdate * 1000).toISOString()}`);
	console.log("===============================\n");

	return rateInfo;
}

// yarn hardhat get-rate-info [--dstchain <chain_name>] --network <network_name>
task("get-rate-info", "Get rate limit information for LancaCanonicalBridge contracts")
	.addOptionalParam(
		"dstchain",
		"Destination chain name (required for L1 bridge, omit for other bridges to default to Ethereum)",
	)
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await getRateInfoTask(taskArgs, hre);
	});

export { getRateInfoTask };
