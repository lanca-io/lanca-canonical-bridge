import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { getEnvVar, log, updateEnvVariable } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
) => Promise<Deployment>;

const deployLancaCanonicalBridgePoolProxy: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name: chainName } = hre.network;
	const chain = conceroNetworks[chainName];
	const { type: networkType } = chain;

	const proxyAdmin = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!proxyAdmin) {
		throw new Error(
			`Pool proxy admin address not found. Set LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)} in environment variables.`,
		);
	}

	const newImplementation = getEnvVar(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!newImplementation) {
		throw new Error(
			`Pool implementation address not found. Set LC_BRIDGE_POOL_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)} in environment variables.`,
		);
	}

	log("Deploying...", "deployLancaCanonicalBridgePoolProxy", chainName);
	const lancaPoolProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
		from: proxyDeployer,
		args: [newImplementation, proxyAdmin, "0x"],
		log: true,
		autoMine: true,
	})) as Deployment;

	log(
		`Deployed at: ${lancaPoolProxyDeployment.address}. Initial impl: ${newImplementation}, Proxy admin: ${proxyDeployer}`,
		"deployLancaCanonicalBridgePoolProxy",
		chainName,
	);
	updateEnvVariable(
		`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(chainName)}_${getNetworkEnvKey(dstChainName)}`,
		lancaPoolProxyDeployment.address,
		`deployments.${networkType}`,
	);

	return lancaPoolProxyDeployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgePoolProxy as any).tags = ["LancaCanonicalBridgePoolProxy"];

export { deployLancaCanonicalBridgePoolProxy };
