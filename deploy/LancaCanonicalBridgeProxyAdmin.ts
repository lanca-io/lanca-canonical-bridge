import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { IProxyType } from "../types/deploymentVariables";
import { getGasParameters, getWallet, log, updateEnvAddress } from "../utils";

const deployLancaCanonicalBridgeProxyAdmin: (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) {
	const { proxyDeployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;
	const networkType = conceroNetworks[name].type;

	const initialOwner = getWallet(networkType, "proxyDeployer", "address");
	const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name]);

	log("Deploying...", `deployLancaCanonicalBridgeProxyAdmin: ${proxyType}`, name);
	const deployProxyAdmin = (await deploy("LancaCanonicalBridgeProxyAdmin", {
		from: proxyDeployer,
		args: [initialOwner],
		log: true,
		autoMine: true,
		skipIfAlreadyDeployed: false,
		gasLimit: 3000000,
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
};

// Assign tags to the function
(deployLancaCanonicalBridgeProxyAdmin as any).tags = ["LancaCanonicalBridgeProxyAdmin"];

export { deployLancaCanonicalBridgeProxyAdmin };
