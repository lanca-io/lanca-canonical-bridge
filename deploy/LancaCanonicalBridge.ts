import type { ConceroNetwork, IDeployResult } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { EnvFileName } from "../types/deploymentVariables";
import { err, genericDeploy, getEnvVar, getNetworkEnvKey, updateEnvVariable } from "../utils/";

type DeployArgs = {
	l1ChainSelector?: bigint;
	conceroRouter: string;
	usdcAddress: string;
	l1BridgeAddress?: string;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<IDeployResult>;

export const deployLancaCanonicalBridge: DeploymentFunction = async (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
): Promise<IDeployResult> => {
	const { name } = hre.network;

	const srcChain = conceroNetworks[name as keyof typeof conceroNetworks];
	const { type: networkType } = srcChain;

	const isL1Deployment = name === "ethereum" || name === "ethereumSepolia";

	// if deploy to other chian instead of ethereum, we need to set ethereum as dstChain
	let dstChain: ConceroNetwork;
	let l1BridgeAddress: string;
	let l1ChainSelector: bigint;
	if (!isL1Deployment) {
		dstChain = (
			networkType === "testnet" ? conceroNetworks.ethereumSepolia : conceroNetworks.ethereum
		) as ConceroNetwork;

		l1BridgeAddress = getEnvVar(`LC_BRIDGE_PROXY_${getNetworkEnvKey(dstChain.name)}`) || "";
		l1ChainSelector = BigInt(dstChain.chainId);
		if (!l1BridgeAddress || !l1ChainSelector) {
			err(
				`L1 Bridge address of L1 chain selector ${l1ChainSelector} not found. Set LC_BRIDGE_PROXY_${getNetworkEnvKey(dstChain.name)} in .env.deployments.${networkType} variables.`,
				"deployLancaCanonicalBridge",
				name,
			);
		}
	} else {
		l1BridgeAddress = "";
		l1ChainSelector = 0n;
	}

	const conceroRouter = getEnvVar(`CONCERO_ROUTER_PROXY_${getNetworkEnvKey(name)}`);
	if (!conceroRouter) {
		err(
			`ConceroRouter address not found. Set CONCERO_ROUTER_PROXY_${getNetworkEnvKey(name)} in .env.deployments.${networkType} variables.`,
			"deployLancaCanonicalBridge",
			name,
		);
	}

	const usdcAddress = getEnvVar(`USDC_PROXY_${getNetworkEnvKey(name)}`);
	if (!usdcAddress) {
		err(
			`USDC address not found. Set USDC_PROXY_${getNetworkEnvKey(name)} in .env.deployments.${networkType} variables.`,
			"deployLancaCanonicalBridge",
			name,
		);
	}

	if (!conceroRouter || !usdcAddress) {
		return {} as IDeployResult;
	}

	const defaultArgs: DeployArgs = {
		l1ChainSelector,
		conceroRouter,
		usdcAddress,
		l1BridgeAddress,
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	let constructorArgs;
	let constructorName;

	if (!isL1Deployment) {
		constructorName = "LancaCanonicalBridge";
		constructorArgs = [
			args.l1ChainSelector,
			args.conceroRouter,
			args.usdcAddress,
			args.l1BridgeAddress,
		];
	} else {
		constructorName = "LancaCanonicalBridgeL1";
		constructorArgs = [args.conceroRouter, args.usdcAddress];
	}

	const deployment = await genericDeploy(
		{
			hre,
			contractName: constructorName,
		},
		...constructorArgs,
	);

	updateEnvVariable(
		`LC_BRIDGE_${getNetworkEnvKey(deployment.chainName)}`,
		deployment.address,
		`deployments.${deployment.chainType}` as EnvFileName,
	);

	return deployment;
};
