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
	const { name: srcChainName } = hre.network;
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	log("Deploying FiatTokenProxyAdmin...", "deployFiatTokenProxyAdmin", srcChainName);

	const implementation = getEnvVar(`USDC_${getNetworkEnvKey(srcChainName)}`);

	const deployment = await deploy("AdminUpgradeabilityProxy", {
		from: proxyDeployer,
		args: [implementation],
		log: true,
		autoMine: true,
	});

	log(
		`Deployment completed: ${deployment.address} \n`,
		"deployFiatTokenProxyAdmin",
		srcChainName,
	);

	updateEnvVariable(
		`USDC_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	return deployment;
};

(deployFiatTokenProxyAdmin as any).tags = ["FiatTokenProxyAdmin"];

export default deployFiatTokenProxyAdmin;
export { deployFiatTokenProxyAdmin };
