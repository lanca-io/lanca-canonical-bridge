import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar, getGasParameters, log, updateEnvVariable } from "../utils/";

type DeployArgs = {
	conceroRouter: string;
	chainSelector: bigint;
	usdcAddress: string;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<Deployment>;

const deployLancaCanonicalBridge: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
): Promise<Deployment> {
	const { deployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const chain = conceroNetworks[name];
	const { type: networkType } = chain;

	const conceroRouterAddress = getEnvVar(`CONCERO_ROUTER_PROXY_${getNetworkEnvKey(name)}`);

	if (!conceroRouterAddress) {
		throw new Error(
			`ConceroRouter address not found. Set CONCERO_ROUTER_PROXY_${getNetworkEnvKey(name)} in environment variables.`,
		);
	}

	const usdcAddress = getEnvVar(`USDC_${getNetworkEnvKey(name)}`);

	if (!usdcAddress) {
		throw new Error(
			`USDC address not found. Set USDC_${getNetworkEnvKey(name)} in environment variables.`,
		);
	}

	const defaultArgs: DeployArgs = {
		conceroRouter: conceroRouterAddress,
		chainSelector: chain.chainSelector,
		usdcAddress: usdcAddress,
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	log(`Deploying LancaCanonicalBridge with args:`, "deployLancaCanonicalBridge", name);
	log(`  conceroRouter: ${args.conceroRouter}`, "deployLancaCanonicalBridge", name);
	log(`  chainSelector: ${args.chainSelector}`, "deployLancaCanonicalBridge", name);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridge", name);

	const deployment = await deploy("LancaCanonicalBridge", {
		from: deployer,
		args: [args.conceroRouter, args.chainSelector, args.usdcAddress],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployLancaCanonicalBridge", name);

	updateEnvVariable(
		`LANCA_CANONICAL_BRIDGE_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	return deployment;
};

// Assign tags to the function
(deployLancaCanonicalBridge as any).tags = ["LancaCanonicalBridge"];

export default deployLancaCanonicalBridge;
export { deployLancaCanonicalBridge };
