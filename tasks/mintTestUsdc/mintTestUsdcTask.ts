import fs from "fs";
import path from "path";

import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { conceroNetworks, getViemReceiptConfig } from "../../constants";
import { err, getEnvVar, getFallbackClients, getViemAccount, log } from "../../utils";

async function mintTestUsdcTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	const { to, amount } = taskArgs;

	const { name } = hre.network;
	const { viemChain, type: networkType } = conceroNetworks[name];

	const fiatTokenProxyAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)}`);

	const fiatTokenArtifactPath = path.resolve(
		__dirname,
		"../../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	);
	const fiatTokenArtifact = JSON.parse(fs.readFileSync(fiatTokenArtifactPath, "utf8"));

	const viemAccount = getViemAccount(networkType, "deployer");
	const { walletClient, publicClient } = getFallbackClients(conceroNetworks[name], viemAccount);

	try {
		const mintTxHash = await walletClient.writeContract({
			address: fiatTokenProxyAddress as `0x${string}`,
			abi: fiatTokenArtifact.abi,
			functionName: "mint",
			account: viemAccount,
			args: [to, amount],
			chain: viemChain,
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[name]),
			hash: mintTxHash,
		});

		log(`Minted ${amount} USDC to ${to}`, "mintTestUsdc", name);
	} catch (error) {
		err(`Failed to mint USDC: ${error}`, "mintTestUsdc", name);
	}
}

task("mint-test-usdc", "Mint Test USDC")
	.addParam("to", "The address to mint USDC to")
	.addParam("amount", "The amount of USDC to mint")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await mintTestUsdcTask(taskArgs, hre);
	});

export { mintTestUsdcTask };