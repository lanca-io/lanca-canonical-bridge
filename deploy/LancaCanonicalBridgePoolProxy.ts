import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { getEnvAddress, log, updateEnvAddress } from "../utils";

const deployLancaCanonicalBridgePoolProxy: (hre: HardhatRuntimeEnvironment) => Promise<void> =
	async function (hre: HardhatRuntimeEnvironment) {
		const { proxyDeployer } = await hre.getNamedAccounts();
		const { deploy } = hre.deployments;
		const { name, live } = hre.network;
		const chain = conceroNetworks[name];
		const { type } = chain;

		const [initialImplementation, initialImplementationAlias] = getEnvAddress(
			"lcBridgePool",
			name,
		);
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
		updateEnvAddress(
			"lcBridgePoolProxy",
			name,
			lancaPoolProxyDeployment.address,
			`deployments.${type}`,
		);
	};

// Assign tags to the function
(deployLancaCanonicalBridgePoolProxy as any).tags = ["LancaCanonicalBridgePoolProxy"];

export { deployLancaCanonicalBridgePoolProxy };
