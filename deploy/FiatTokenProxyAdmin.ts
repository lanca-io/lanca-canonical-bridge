import { getNetworkEnvKey } from "@concero/contract-utils";
import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { getEnvVar, getFallbackClients, getViemAccount, log, updateEnvVariable } from "../utils";

const deployFiatTokenProxyAdmin = async function (
	hre: HardhatRuntimeEnvironment,
): Promise<Deployment> {
	const { name: srcChainName } = hre.network;
	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const implementation = getEnvVar(`USDC_${getNetworkEnvKey(srcChainName)}`);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { publicClient } = getFallbackClients(srcChain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config) {
		gasLimit = config.proxyAdmin?.gasLimit || 0;
	}

	const deployment = await hardhatDeployWrapper("AdminUpgradeabilityProxy", {
		hre,
		args: [implementation],
		publicClient,
		proxy: true,
		gasLimit,
	});

	log(
		`Deployment completed: ${deployment.address} \n`,
		"deployFiatTokenProxyAdmin",
		srcChainName,
	);

	updateEnvVariable(
		`USDC_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	return deployment;
};

(deployFiatTokenProxyAdmin as any).tags = ["FiatTokenProxyAdmin"];

export default deployFiatTokenProxyAdmin;
export { deployFiatTokenProxyAdmin };
