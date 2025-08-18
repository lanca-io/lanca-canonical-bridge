import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { IProxyType } from "../types/deploymentVariables";
import { getEnvAddress, log, updateEnvAddress } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<Deployment>;

const deployLancaCanonicalBridgeProxy: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
): Promise<Deployment> {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;
	const chain = conceroNetworks[name];
	const { type } = chain;

	const [initialImplementation, initialImplementationAlias] = getEnvAddress("lcBridge", name);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, name);

	log("Deploying...", `deployLancaCanonicalBridgeProxy:${proxyType}`, name);
	const lancaProxyDeployment = (await deploy("LCBTransparentUpgradeableProxy", {
		from: proxyDeployer,
		args: [initialImplementation, proxyAdmin, "0x"],
		log: true,
		autoMine: true,
	})) as Deployment;

	log(
		`Deployed at: ${lancaProxyDeployment.address}. Initial impl: ${initialImplementationAlias}, Proxy admin: ${proxyAdminAlias}`,
		`deployLancaCanonicalBridgeProxy: ${proxyType}`,
		name,
	);
	updateEnvAddress(proxyType, name, lancaProxyDeployment.address, `deployments.${type}`);

	return lancaProxyDeployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgeProxy as any).tags = ["LancaCanonicalBridgeProxy"];

export { deployLancaCanonicalBridgeProxy };
