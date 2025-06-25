import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { addLane } from "../utils";

async function addLaneTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await addLane(hre, taskArgs.chain);
}

// yarn hardhat add-lane --chain <destination_chain_name> --network <network_name>
task("add-lane", "Add lane to LancaCanonicalBridge")
	.addParam("chain", "Destination chain name for the lane")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await addLaneTask(taskArgs, hre);
	});

export { addLaneTask };
