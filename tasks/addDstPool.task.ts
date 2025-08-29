import { task } from "hardhat/config";

import { addPool } from "./utils";

async function addDstPoolTask(taskArgs: any) {
	await addPool(taskArgs.dstchain);
}

// yarn hardhat add-dst-pool --dstchain <destination_chain_name>
task("add-dst-pool", "Add destination pool to LancaCanonicalBridgeL1")
	.addParam("dstchain", "Destination chain name for the pool")
	.setAction(async (taskArgs) => {
		await addDstPoolTask(taskArgs);
	});

export { addDstPoolTask };
