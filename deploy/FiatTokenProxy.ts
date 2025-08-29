import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../constants";
import { copyMetadataForVerification, saveVerificationData } from "../tasks/utils";
import {
	err,
	getEnvVar,
	getFallbackClients,
	getViemAccount,
	log,
	updateEnvVariable,
} from "../utils";

const deployFiatTokenProxy = async function (hre: HardhatRuntimeEnvironment): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name: srcChainName } = hre.network;
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const implementation = getEnvVar(`USDC_${getNetworkEnvKey(srcChainName)}`);

	log("Deploying FiatTokenProxy...", "deployFiatTokenProxy", srcChainName);

	const deployment = await deploy("FiatTokenProxy", {
		from: proxyDeployer,
		args: [implementation],
		log: true,
		autoMine: true,
	});

	log(`Deployment completed: ${deployment.address} \n`, "deployFiatTokenProxy", srcChainName);

	updateEnvVariable(
		`USDC_PROXY_${getNetworkEnvKey(srcChainName)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	const fiatTokenProxyAdminAddress = getEnvVar(
		`USDC_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}`,
	);

	const { abi: fiatTokenProxyAbi } = await import(
		"../artifacts/contracts/usdc/v1/FiatTokenProxy.sol/FiatTokenProxy.json"
	);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	try {
		const changeAdminTxHash = await walletClient.writeContract({
			address: deployment.address as `0x${string}`,
			abi: fiatTokenProxyAbi,
			functionName: "changeAdmin",
			account: viemAccount,
			args: [fiatTokenProxyAdminAddress as `0x${string}`],
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(srcChain),
			hash: changeAdminTxHash,
		});

		log(`Change admin completed: ${changeAdminTxHash}`, "deployFiatTokenProxy", srcChainName);
	} catch (error) {
		err(`Failed to change admin: ${error}`, "deployFiatTokenProxy", srcChainName);
	}

	try {
		await saveVerificationData(
			srcChainName,
			"FiatTokenProxy",
			deployment.address,
			deployment.transactionHash || "",
		);
		await copyMetadataForVerification(srcChainName, "FiatTokenProxy");
	} catch (error) {
		log(
			`Warning: Failed to save verification data: ${error}`,
			"deployFiatTokenProxy",
			srcChainName,
		);
	}

	return deployment;
};

(deployFiatTokenProxy as any).tags = ["FiatTokenProxy"];

export default deployFiatTokenProxy;
export { deployFiatTokenProxy };
