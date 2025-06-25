import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getWallet, log, updateEnvVariable } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
) => Promise<Deployment>;

const deployLancaCanonicalBridgePoolProxyAdmin: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	const initialOwner = getWallet(networkType, "proxyDeployer", "address");

	log("Deploying...", "deployLancaCanonicalBridgePoolProxyAdmin", name);
	const deployProxyAdmin = (await deploy("LancaCanonicalBridgeProxyAdmin", {
		from: proxyDeployer,
		args: [initialOwner],
		log: true,
		autoMine: true,
	})) as Deployment;

	log(
		`Deployed at: ${deployProxyAdmin.address}`,
		"deployLancaCanonicalBridgePoolProxyAdmin",
		name,
	);
	updateEnvVariable(
		`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`,
		deployProxyAdmin.address,
		`deployments.${networkType}`,
	);

	return deployProxyAdmin;
};

// Assign tags to the function
(deployLancaCanonicalBridgePoolProxyAdmin as any).tags = ["LancaCanonicalBridgePoolProxyAdmin"];

export { deployLancaCanonicalBridgePoolProxyAdmin };
