import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { IProxyType } from "../types/deploymentVariables";
import { getWallet, log, updateEnvAddress } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<Deployment>;

const deployLancaCanonicalBridgeProxyAdmin: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	const initialOwner = getWallet(networkType, "proxyDeployer", "address");

	log("Deploying...", `deployLancaCanonicalBridgeProxyAdmin: ${proxyType}`, name);
	const deployProxyAdmin = (await deploy("LancaCanonicalBridgeProxyAdmin", {
		from: proxyDeployer,
		args: [initialOwner],
		log: true,
		autoMine: true,
	})) as Deployment;

	log(
		`Deployed at: ${deployProxyAdmin.address}`,
		`deployLancaCanonicalBridgeProxyAdmin: ${proxyType}`,
		name,
	);
	updateEnvAddress(
		`${proxyType}Admin`,
		name,
		deployProxyAdmin.address,
		`deployments.${networkType}`,
	);

	return deployProxyAdmin;
};

// Assign tags to the function
(deployLancaCanonicalBridgeProxyAdmin as any).tags = ["LancaCanonicalBridgeProxyAdmin"];

export { deployLancaCanonicalBridgeProxyAdmin };
