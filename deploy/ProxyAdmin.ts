import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getWallet, log, updateEnvVariable } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	envPrefix: string,
	overrideOwner?: string,
	dstChainName?: string,
) => Promise<Deployment>;

const deployProxyAdmin: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	envPrefix: string,
	overrideOwner?: string,
	dstChainName?: string,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	const initialOwner = overrideOwner || getWallet(networkType, "proxyDeployer", "address");

	log(`Deploying ProxyAdmin...`, "deployProxyAdmin", name);
	log(`  initialOwner: ${initialOwner}`, "deployProxyAdmin", name);

	const deployment = await deploy("ProxyAdmin", {
		from: proxyDeployer,
		args: [initialOwner],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployProxyAdmin", name);

	let envVarName: string;
	if (dstChainName) {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`;
	} else {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}`;
	}
	updateEnvVariable(envVarName, deployment.address, `deployments.${networkType}`);

	return deployment;
};

// Assign tags to the function
(deployProxyAdmin as any).tags = ["ProxyAdmin"];

export { deployProxyAdmin };
export default deployProxyAdmin;
