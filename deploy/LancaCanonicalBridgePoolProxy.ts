import { getNetworkEnvKey } from "@concero/contract-utils";
import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import {
	err,
	getEnvVar,
	getFallbackClients,
	getViemAccount,
	log,
	updateEnvVariable,
} from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
) => Promise<Deployment>;

const deployLancaCanonicalBridgePoolProxy: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
): Promise<Deployment> {
	const { name: srcChainName } = hre.network;

	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const proxyAdmin = getEnvVar(
		`LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!proxyAdmin) {
		err(
			`Pool proxy admin address not found. Set LC_BRIDGE_POOL_PROXY_ADMIN_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)} in environment variables.`,
			"deployLancaCanonicalBridgePoolProxy",
			srcChainName,
		);
	}

	const newImplementation = getEnvVar(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
	);
	if (!newImplementation) {
		err(
			`Pool implementation address not found. Set LC_BRIDGE_POOL_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)} in environment variables.`,
			"deployLancaCanonicalBridgePoolProxy",
			srcChainName,
		);
	}

	if (!srcChain || !proxyAdmin || !newImplementation) {
		return {} as Deployment;
	}

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { publicClient } = getFallbackClients(srcChain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config) {
		gasLimit = config.proxy?.gasLimit || 0;
	}

	const lancaPoolProxyDeployment = await hardhatDeployWrapper("LCBTransparentUpgradeableProxy", {
		hre,
		args: [newImplementation, proxyAdmin, "0x"],
		publicClient,
		gasLimit,
		proxy: true,
	});

	log(
		`Deployed at: ${lancaPoolProxyDeployment.address}. Initial impl: ${newImplementation}, Proxy admin: ${proxyAdmin}`,
		"deployLancaCanonicalBridgePoolProxy",
		srcChainName,
	);
	updateEnvVariable(
		`LC_BRIDGE_POOL_PROXY_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
		lancaPoolProxyDeployment.address,
		`deployments.${networkType}`,
	);

	return lancaPoolProxyDeployment;
};

export { deployLancaCanonicalBridgePoolProxy };
