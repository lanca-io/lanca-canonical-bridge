import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { removeDstPool } from "../utils";

async function removeDstPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await removeDstPool(hre, taskArgs.chain);
}

// yarn hardhat remove-dst-pool --chain <destination_chain_name> --network <network_name>
task("remove-dst-pool", "Remove destination pool from LancaCanonicalBridgeL1")
	.addParam("chain", "Destination chain name for the pool to remove")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await removeDstPoolTask(taskArgs, hre);
	});

export { removeDstPoolTask };
