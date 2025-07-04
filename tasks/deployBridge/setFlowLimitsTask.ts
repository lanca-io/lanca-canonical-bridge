import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { setFlowLimits } from "../utils";

async function setFlowLimitsTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await setFlowLimits(
		hre,
		taskArgs.dstchain,
		taskArgs.outmax,
		taskArgs.outrefill,
		taskArgs.inmax,
		taskArgs.inrefill,
	);
}

// yarn hardhat set-flow-limits [--dstchain <chain_name>] [--outmax <amount>] [--outrefill <speed>] [--inmax <amount>] [--inrefill <speed>] --network <network_name>
task("set-flow-limits", "Set flow limits for LancaCanonicalBridge contracts")
	.addOptionalParam(
		"dstchain",
		"Destination chain name (required for L1 bridge, omit for L2 bridge)",
	)
	.addOptionalParam("outmax", "Maximum outbound flow amount (in wei)")
	.addOptionalParam("outrefill", "Outbound refill speed (tokens per second in wei)")
	.addOptionalParam("inmax", "Maximum inbound flow amount (in wei)")
	.addOptionalParam("inrefill", "Inbound refill speed (tokens per second in wei)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await setFlowLimitsTask(taskArgs, hre);
	});

export { setFlowLimitsTask };
