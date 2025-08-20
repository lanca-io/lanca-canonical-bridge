import { task } from "hardhat/config";

import { addDstBridge } from "./utils";

async function addDstBridgeTask(taskArgs: any) {
	await addDstBridge(taskArgs.dstchain);
}

// yarn hardhat add-dst-bridge --dstchain <destination_chain_name>
task("add-dst-bridge", "Add destination bridge to LancaCanonicalBridgeL1")
	.addParam("dstchain", "Destination dstchain name for the bridge")
	.setAction(async taskArgs => {
		await addDstBridgeTask(taskArgs);
	});

export { addDstBridgeTask };
