import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { IProxyType } from "../types/deploymentVariables";
import { getEnvAddress, getGasParameters, log, updateEnvAddress } from "../utils";

const deployLancaCanonicalBridgeProxy: (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name, live } = hre.network;
	const chain = conceroNetworks[name];
	const { type } = chain;

	const [initialImplementation, initialImplementationAlias] = getEnvAddress("lcBridge", name);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, name);

	const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(chain);

	log("Deploying...", `deployLancaCanonicalBridgeProxy:${proxyType}`, name);
	const lancaProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
		from: proxyDeployer,
		args: [initialImplementation, proxyAdmin, "0x"],
		log: true,
		autoMine: true,
		// maxFeePerGas,
		// maxPriorityFeePerGas
	})) as Deployment;

	log(
		`Deployed at: ${lancaProxyDeployment.address}. Initial impl: ${initialImplementationAlias}, Proxy admin: ${proxyAdminAlias}`,
		`deployLancaCanonicalBridgeProxy: ${proxyType}`,
		name,
	);
	updateEnvAddress(proxyType, name, lancaProxyDeployment.address, `deployments.${type}`);
};

// Assign tags to the function
(deployLancaCanonicalBridgeProxy as any).tags = ["LancaCanonicalBridgeProxy"];

export { deployLancaCanonicalBridgeProxy };
