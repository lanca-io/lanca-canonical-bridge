import { task } from "hardhat/config";

import { sendToken } from "./utils";

async function sendTokenTask(taskArgs: any) {
	const { from, to, amount, receiver, account } = taskArgs;

	await sendToken({
		srcChain: from,
		dstChain: to,
		amount,
		receiver,
		accountType: account,
	});
}

// yarn hardhat send-token --from <source_network> --to <destination_network> --amount <amount>
// IMPORTANT! Could send tokens only from L1 to L2 or from L2 to L1, not from L2 to L2
task("send-token", "Send tokens from one network to another via bridge")
	.addParam("from", "Source network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("to", "Destination network name (e.g., 'arbitrumSepolia', 'baseSepolia')")
	.addParam("amount", "Amount of USDC to send (e.g., '10.5')")
	.addOptionalParam("receiver", "Recipient address on destination network")
	.addOptionalParam("account", "Donor account type (deployer, rebalancer)")
	.setAction(async taskArgs => {
		await sendTokenTask(taskArgs);
	});

export { sendTokenTask };
