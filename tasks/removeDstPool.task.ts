import { task } from "hardhat/config";

import { removeDstPool } from "./utils";

async function removeDstPoolTask(taskArgs: any) {
	await removeDstPool(taskArgs.dstchain);
}

// yarn hardhat remove-dst-pool --dstchain <destination_chain_name>
task("remove-dst-pool", "Remove destination pool from LancaCanonicalBridgeL1")
	.addParam("dstchain", "Destination chain name for the pool to remove")
	.setAction(async (taskArgs) => {
		await removeDstPoolTask(taskArgs);
	});

export { removeDstPoolTask };
