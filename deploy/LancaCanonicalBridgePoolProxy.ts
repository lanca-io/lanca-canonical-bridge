import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvAddress, log, updateEnvVariable } from "../utils";

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
	const { name } = hre.network;
	const chain = conceroNetworks[name];
	const { type: networkType } = chain;

	const [initialImplementation, initialImplementationAlias] = getEnvAddress("lcBridgePool", name);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress("lcBridgePoolProxyAdmin", name);

	log("Deploying...", "deployLancaCanonicalBridgePoolProxy", name);
	const lancaPoolProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
		from: proxyDeployer,
		args: [initialImplementation, proxyAdmin, "0x"],
		log: true,
		autoMine: true,
	})) as Deployment;

	log(
		`Deployed at: ${lancaPoolProxyDeployment.address}. Initial impl: ${initialImplementationAlias}, Proxy admin: ${proxyAdminAlias}`,
		"deployLancaCanonicalBridgePoolProxy",
		name,
	);
	updateEnvVariable(
		`LANCA_CANONICAL_BRIDGE_POOL_PROXY_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`,
		lancaPoolProxyDeployment.address,
		`deployments.${networkType}`,
	);

	return lancaPoolProxyDeployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgePoolProxy as any).tags = ["LancaCanonicalBridgePoolProxy"];

export { deployLancaCanonicalBridgePoolProxy };
