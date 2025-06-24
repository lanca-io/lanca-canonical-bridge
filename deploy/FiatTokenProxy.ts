import fs from "fs";
import path from "path";

import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar, log, updateEnvVariable } from "../utils";

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

	return deployment;
};

(deployFiatTokenProxy as any).tags = ["FiatTokenProxy"];

export default deployFiatTokenProxy;
export { deployFiatTokenProxy };