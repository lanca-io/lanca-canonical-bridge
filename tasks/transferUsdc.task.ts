import { task } from "hardhat/config";

import { TokenSender, getNetworkEnvKey } from "@concero/contract-utils";
import { Address } from "viem";

import {
	ConceroMainnetNetworkNames,
	ConceroTestnetNetworkNames,
	conceroNetworks,
} from "../constants";
import { getEnvVar, getFallbackClients } from "../utils";

async function sendTokenTask(
	amount: string,
	recipients: Address[],
	networkName: ConceroTestnetNetworkNames | ConceroMainnetNetworkNames,
) {
	const { walletClient, publicClient } = getFallbackClients(conceroNetworks[networkName]);

	const tokenSender = new TokenSender(walletClient, publicClient);
	const usdcAddress = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(networkName)}`) as Address;

	for (const recipient of recipients) {
		await tokenSender.sendToken(usdcAddress, amount, recipient);
	}
}

task("transfer-usdc")
	.addParam("amount", "Amount to send (13.35)")
	.addParam("recipients", "Comma-separated recipients addresses")
	.setAction(async taskArgs => {
		const hre = require("hardhat");
		await sendTokenTask(taskArgs.amount, taskArgs.recipients.split(","), hre.network.name);
	});

export default {};
