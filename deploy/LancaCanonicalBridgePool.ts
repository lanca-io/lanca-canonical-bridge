import { IDeployResult } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { EnvFileName } from "../types/deploymentVariables";
import { err, genericDeploy, getEnvVar, getNetworkEnvKey, updateEnvVariable } from "../utils/";

type DeployArgs = {
	usdcAddress: string;
	lancaCanonicalBridgeAddress: string;
	dstChainSelector: bigint;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<IDeployResult>;

export const deployLancaCanonicalBridgePool: DeploymentFunction = async (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
): Promise<IDeployResult> => {
	const { name: srcChainName } = hre.network;
	const dstChain = conceroNetworks[dstChainName as keyof typeof conceroNetworks];

	if (!dstChain) {
		err(
			`Destination chain ${dstChainName} not found.`,
			"deployLancaCanonicalBridgePool",
			srcChainName,
		);
	}

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LC_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);

	if (!lancaCanonicalBridgeAddress) {
		err(
			`LancaCanonicalBridge address not found. Set LC_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in environment variables.`,
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
		return {} as IDeployResult;
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

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config) {
		gasLimit = config.pool?.gasLimit || 0;
	}

	const deployment = await genericDeploy(
		{
			hre,
			contractName: "LancaCanonicalBridgePool",
			txParams: {
				gasLimit: BigInt(gasLimit),
			},
		},
		args.usdcAddress,
		args.lancaCanonicalBridgeAddress,
		args.dstChainSelector,
	);

	updateEnvVariable(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(dstChainName)}`,
		deployment.address,
		`deployments.${deployment.chainType}` as EnvFileName,
	);

	return deployment;
};
