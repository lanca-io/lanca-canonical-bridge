import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { setRateLimits } from "../utils";

async function setRateLimitsTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await setRateLimits(
		hre.network.name,
		taskArgs.dstchain,
		taskArgs.outmax,
		taskArgs.outrefill,
		taskArgs.inmax,
		taskArgs.inrefill,
	);
}

// yarn hardhat set-rate-limits [--dstchain <chain_name>] [--outmax <amount>] [--outrefill <speed>] [--inmax <amount>] [--inrefill <speed>] --network <network_name>
task("set-rate-limits", "Set rate limits for LancaCanonicalBridge contracts")
	.addOptionalParam(
		"dstchain",
		"Destination chain name (required for L1 bridge, omit for L2 bridge)",
	)
	.addOptionalParam("outmax", "Maximum outbound rate amount (in USDC)")
	.addOptionalParam("outrefill", "Outbound refill speed (USDC per second)")
	.addOptionalParam("inmax", "Maximum inbound rate amount (in USDC)")
	.addOptionalParam("inrefill", "Inbound refill speed (USDC per second)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await setRateLimitsTask(taskArgs, hre);
	});

export { setRateLimitsTask };
