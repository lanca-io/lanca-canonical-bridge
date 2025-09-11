import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { IProxyType } from "../types/deploymentVariables";
import { getEnvAddress, getFallbackClients, getViemAccount, log, updateEnvAddress } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<Deployment>;

const deployLancaCanonicalBridgeProxy: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
): Promise<Deployment> {
	const { name } = hre.network;
	const chain = conceroNetworks[name];
	const { type } = chain;

	const [initialImplementation, initialImplementationAlias] = getEnvAddress("lcBridge", name);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, name);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { publicClient } = getFallbackClients(chain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[name];
	if (config) {
		gasLimit = config.proxy?.gasLimit || 0;
	}

	const lancaProxyDeployment = await hardhatDeployWrapper("LCBTransparentUpgradeableProxy", {
		hre,
		args: [initialImplementation, proxyAdmin, "0x"],
		publicClient,
		proxy: true,
		gasLimit,
	});

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
