import { getNetworkEnvKey } from "@concero/contract-utils";
import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
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
	const { name: srcChainName } = hre.network;
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const implementation = getEnvVar(`USDC_${getNetworkEnvKey(srcChainName)}`);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(srcChain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config) {
		gasLimit = config.proxy?.gasLimit || 0;
	}

	const deployment = await hardhatDeployWrapper("FiatTokenProxy", {
		hre,
		args: [implementation],
		publicClient,
		proxy: true,
		gasLimit,
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
