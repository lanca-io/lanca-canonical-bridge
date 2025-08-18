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

	const implementation = getEnvVar(`FIAT_TOKEN_IMPLEMENTATION_${getNetworkEnvKey(name)}`);

	const deployment = await deploy("AdminUpgradeabilityProxy", {
		from: proxyDeployer,
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
