import { task } from "hardhat/config";

import { removeDstBridge } from "../utils";

async function removeDstBridgeTask(taskArgs: any) {
	await removeDstBridge(taskArgs.dstchain);
}

// yarn hardhat remove-dst-bridge --dstchain <destination_chain_name>
task("remove-dst-bridge", "Remove destination bridge from LancaCanonicalBridgeL1")
	.addParam("dstchain", "Destination chain name for the bridge to remove")
	.setAction(async taskArgs => {
		await removeDstBridgeTask(taskArgs);
	});

export { removeDstBridgeTask };
