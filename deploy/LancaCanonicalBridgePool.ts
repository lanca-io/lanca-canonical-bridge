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
} from "../utils/";

type DeployArgs = {
	usdcAddress: string;
	lancaCanonicalBridgeAddress: string;
	dstChainSelector: bigint;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<Deployment>;

const deployLancaCanonicalBridgePool: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
): Promise<Deployment> {
	const { name: srcChainName } = hre.network;

	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];

	if (!dstChain) {
		err(
			`Destination chain ${dstChainName} not found.`,
			"deployLancaCanonicalBridgePool",
			srcChainName,
		);
	}

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);

	if (!lancaCanonicalBridgeAddress) {
		err(
			`LancaCanonicalBridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in environment variables.`,
			"deployLancaCanonicalBridgePool",
			srcChainName,
		);
	}

	const usdcAddress = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(srcChainName)}`);
	if (!usdcAddress) {
		err(
			`USDC address not found. Set USDC_PROXY_${getNetworkEnvKey(srcChainName)} in environment variables.`,
			"deployLancaCanonicalBridgePool",
			srcChainName,
		);
	}

	if (!dstChain || !usdcAddress || !lancaCanonicalBridgeAddress) {
		return {} as Deployment;
	}

	const defaultArgs: DeployArgs = {
		usdcAddress: usdcAddress,
		lancaCanonicalBridgeAddress: lancaCanonicalBridgeAddress,
		dstChainSelector: BigInt(dstChain.chainSelector),
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	const viemAccount = getViemAccount(networkType, "deployer");
	const { publicClient } = getFallbackClients(srcChain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config) {
		gasLimit = config.pool?.gasLimit || 0;
	}

	const deployment = await hardhatDeployWrapper("LancaCanonicalBridgePool", {
		hre,
		args: [args.usdcAddress, args.lancaCanonicalBridgeAddress, args.dstChainSelector],
		publicClient,
		gasLimit,
	});

	log(`Deployed at: ${deployment.address}`, "deployLancaCanonicalBridgePool", srcChainName);

	updateEnvVariable(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChainName)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	return deployment;
};

export default deployLancaCanonicalBridgePool;
export { deployLancaCanonicalBridgePool };
