import fs from "fs";
import path from "path";

import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { getEnvVar, log, updateEnvVariable } from "../utils";

const deployFiatTokenProxyAdmin = async function (
	hre: HardhatRuntimeEnvironment,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const networkType = conceroNetworks[name].type;

	log("Deploying FiatTokenProxyAdmin...", "deployFiatTokenProxyAdmin", name);

	// const adminUpgradeableProxyArtifactPath = path.resolve(
	// 	__dirname,
	// 	"../usdc-artifacts/AdminUpgradeabilityProxy.sol/AdminUpgradeabilityProxy.json",
	// );

	// const adminUpgradableProxyArtifact = JSON.parse(
	// 	fs.readFileSync(adminUpgradeableProxyArtifactPath, "utf8"),
	// );

	const implementation = getEnvVar(`FIAT_TOKEN_IMPLEMENTATION_${getNetworkEnvKey(name)}`);

	const deployment = await deploy("FiatTokenProxyAdmin", {
		from: proxyDeployer,
		// contract: {
		// 	abi: adminUpgradableProxyArtifact.abi,
		// 	bytecode: adminUpgradableProxyArtifact.bytecode,
		// },
		args: [implementation],
		log: true,
		autoMine: true,
	});

	log(`Deployment completed: ${deployment.address} \n`, "deployFiatTokenProxyAdmin", name);

	updateEnvVariable(
		`FIAT_TOKEN_PROXY_ADMIN_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	return deployment;
};

(deployFiatTokenProxyAdmin as any).tags = ["FiatTokenProxyAdmin"];

export default deployFiatTokenProxyAdmin;
export { deployFiatTokenProxyAdmin };
