import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks, getViemReceiptConfig } from "../constants";
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
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	const implementation = getEnvVar(`FIAT_TOKEN_IMPLEMENTATION_${getNetworkEnvKey(name)}`);

	log("Deploying FiatTokenProxy...", "deployFiatTokenProxy", name);

	const fiatTokenProxyArtifactPath = path.resolve(
		__dirname,
		"../usdc-artifacts/FiatTokenProxy.sol/FiatTokenProxy.json",
	);

	const fiatTokenProxyArtifact = JSON.parse(fs.readFileSync(fiatTokenProxyArtifactPath, "utf8"));

	const deployment = await deploy("FiatTokenProxy", {
		from: proxyDeployer,
		contract: {
			abi: fiatTokenProxyArtifact.abi,
			bytecode: fiatTokenProxyArtifact.bytecode,
		},
		args: [implementation],
		log: true,
		autoMine: true,
	});

	log(`Deployment completed: ${deployment.address} \n`, "deployFiatTokenProxy", name);

	updateEnvVariable(
		`FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	// TODO: Refactor this
	const fiatTokenProxyAdminAddress = getEnvVar(
		`FIAT_TOKEN_PROXY_ADMIN_${getNetworkEnvKey(name)}`,
	);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { walletClient, publicClient } = getFallbackClients(conceroNetworks[name], viemAccount);

	try {
		const changeAdminTxHash = await walletClient.writeContract({
			address: deployment.address as `0x${string}`,
			abi: fiatTokenProxyArtifact.abi,
			functionName: "changeAdmin",
			account: viemAccount,
			args: [fiatTokenProxyAdminAddress as `0x${string}`],
		});

		await publicClient.waitForTransactionReceipt({
			...getViemReceiptConfig(conceroNetworks[name]),
			hash: changeAdminTxHash,
		});

		log(`Change admin completed: ${changeAdminTxHash}`, "deployFiatTokenProxy", name);
	} catch (error) {
		err(`Failed to change admin: ${error}`, "deployFiatTokenProxy", name);
	}

	return deployment;
};

(deployFiatTokenProxy as any).tags = ["FiatTokenProxy"];

export default deployFiatTokenProxy;
export { deployFiatTokenProxy };
