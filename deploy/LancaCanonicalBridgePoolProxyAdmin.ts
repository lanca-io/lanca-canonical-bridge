import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { getWallet, log, updateEnvAddress } from "../utils";

const deployLancaCanonicalBridgePoolProxyAdmin: (hre: HardhatRuntimeEnvironment) => Promise<void> =
	async function (hre: HardhatRuntimeEnvironment) {
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
		updateEnvAddress(
			"lcBridgePoolProxyAdmin",
			name,
			deployProxyAdmin.address,
			`deployments.${networkType}`,
		);
	};

// Assign tags to the function
(deployLancaCanonicalBridgePoolProxyAdmin as any).tags = ["LancaCanonicalBridgePoolProxyAdmin"];

export { deployLancaCanonicalBridgePoolProxyAdmin };
