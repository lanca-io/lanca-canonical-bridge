import { task } from "hardhat/config";

import { sendToken } from "./utils/sendToken";

async function sendTokenTask(taskArgs: any) {
	const { from, to, amount, receiver } = taskArgs;

	await sendToken({
		srcChain: from,
		dstChain: to,
		amount,
		receiver,
	});
}

// yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount>
task("send-token", "Send tokens from one network to another via bridge")
	.addParam("from", "Source network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("to", "Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("amount", "Amount of USDC to send (e.g., '10.5')")
	.addOptionalParam("receiver", "Recipient address on destination network")
	.setAction(async taskArgs => {
		await sendTokenTask(taskArgs);
	});

export { sendTokenTask };
