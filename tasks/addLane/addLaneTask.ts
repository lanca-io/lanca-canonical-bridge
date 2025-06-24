import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { addLane } from "../utils";

async function addLaneTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await addLane(hre, taskArgs.chainid);
}

task("add-lane", "Add lane to LancaCanonicalBridge")
	.addParam("chainid", "Destination chain id for the lane")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await addLaneTask(taskArgs, hre);
	});

export { addLaneTask };
