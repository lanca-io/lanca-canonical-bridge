import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { addDstBridge } from "../utils";

async function addDstBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await addDstBridge(hre, taskArgs.chain);
}

// yarn hardhat add-dst-bridge --chain <destination_chain_name> --network <network_name>
task("add-dst-bridge", "Add destination bridge to LancaCanonicalBridgeL1")
	.addParam("chain", "Destination chain name for the bridge")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await addDstBridgeTask(taskArgs, hre);
	});

export { addDstBridgeTask };
