import { getNetworkEnvKey } from "@concero/contract-utils";
import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { getFallbackClients, getViemAccount, getWallet, log, updateEnvVariable } from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	envPrefix: string,
	overrideOwner?: string,
	dstChainName?: string,
) => Promise<Deployment>;

const deployProxyAdmin: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	envPrefix: string,
	overrideOwner?: string,
	dstChainName?: string,
): Promise<Deployment> {
	const { name } = hre.network;
	const chain = conceroNetworks[name as keyof typeof conceroNetworks];
	const { type: networkType } = chain;

	const initialOwner = overrideOwner || getWallet(networkType, "proxyDeployer", "address");

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { publicClient } = getFallbackClients(chain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[name];
	if (config) {
		gasLimit = config.proxyAdmin?.gasLimit || 0;
	}

	const deployment = await hardhatDeployWrapper("LCBProxyAdmin", {
		hre,
		args: [initialOwner],
		publicClient,
		proxy: true,
		gasLimit,
	});

	log(`Deployed at: ${deployment.address}`, "deployProxyAdmin", name);

	let envVarName: string;
	if (dstChainName) {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`;
	} else {
		envVarName = `${envPrefix}_${getNetworkEnvKey(name)}`;
	}
	updateEnvVariable(envVarName, deployment.address, `deployments.${networkType}`);

	return deployment;
};

export { deployProxyAdmin };
export default deployProxyAdmin;
