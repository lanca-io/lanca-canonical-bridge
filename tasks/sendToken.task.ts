import { task } from "hardhat/config";

import { sendToken } from "./utils/sendToken";

async function sendTokenTask(taskArgs: any) {
	const { from, to, amount } = taskArgs;

	await sendToken({
		srcChain: from,
		dstChain: to,
		amount,
	});
}

task("send-token", "Send tokens from one network to another via bridge")
	.addParam("from", "Source network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("to", "Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("amount", "Amount of USDC to send (e.g., '10.5')")
	.setAction(async taskArgs => {
		await sendTokenTask(taskArgs);
	});

export { sendTokenTask };
