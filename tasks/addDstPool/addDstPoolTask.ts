import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { addPool } from "../utils";

async function addDstPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await addPool(hre, taskArgs.chain);
}

// yarn hardhat add-dst-pool --chain <destination_chain_name> --network <network_name>
task("add-dst-pool", "Add destination pool to LancaCanonicalBridgeL1")
	.addParam("chain", "Destination chain name for the pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await addDstPoolTask(taskArgs, hre);
	});

export { addDstPoolTask };
