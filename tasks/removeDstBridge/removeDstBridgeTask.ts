import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { removeDstBridge } from "../utils";

async function removeDstBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await removeDstBridge(hre, taskArgs.chain);
}

// yarn hardhat remove-dst-bridge --chain <destination_chain_name> --network <network_name>
task("remove-dst-bridge", "Remove destination bridge from LancaCanonicalBridgeL1")
	.addParam("chain", "Destination chain name for the bridge to remove")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await removeDstBridgeTask(taskArgs, hre);
	});

export { removeDstBridgeTask };
