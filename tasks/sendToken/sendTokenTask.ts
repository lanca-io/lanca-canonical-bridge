import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { sendToken } from "../utils/sendToken";

async function sendTokenTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	const { dstchain, amount, gaslimit } = taskArgs;

	await sendToken(hre, {
		dstChain: dstchain,
		amount,
		gasLimit: gaslimit,
	});
}

task("send-token", "Send tokens from one network to another via bridge")
	.addParam("dstchain", "Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("amount", "Amount of USDC to send (e.g., '10.5')")
	.addParam("gaslimit", "Gas limit for destination transaction (e.g., '200000')")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await sendTokenTask(taskArgs, hre);
	});

export { sendTokenTask };