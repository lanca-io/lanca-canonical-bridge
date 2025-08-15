import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { getEnvVar, log, updateEnvVariable } from "../utils/";

type DeployArgs = {
	conceroRouter: string;
	usdcAddress: string;
	rateLimitAdmin: string;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<Deployment>;

const deployLancaCanonicalBridgeL1: DeploymentFunction = async function (
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

	const usdcAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)}`);

	if (!usdcAddress) {
		throw new Error(
			`USDC address not found. Set FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)} in environment variables.`,
		);
	}

	const rateLimitAdmin = getEnvVar(`TESTNET_RATE_LIMIT_ADMIN_ADDRESS`);
	if (!rateLimitAdmin) {
		throw new Error(
			`Rate limit admin address not found. Set RATE_LIMIT_ADMIN_ADDRESS in environment variables.`,
		);
	}

	const defaultArgs: DeployArgs = {
		conceroRouter: conceroRouterAddress,
		usdcAddress: usdcAddress,
		rateLimitAdmin: rateLimitAdmin,
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	log(`Deploying LancaCanonicalBridgeL1 with args:`, "deployLancaCanonicalBridgeL1", name);
	log(`  conceroRouter: ${args.conceroRouter}`, "deployLancaCanonicalBridgeL1", name);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridgeL1", name);

	const deployment = await deploy("LancaCanonicalBridgeL1", {
		from: deployer,
		args: [args.conceroRouter, args.usdcAddress, args.rateLimitAdmin],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployLancaCanonicalBridgeL1", name);

	updateEnvVariable(
		`LANCA_CANONICAL_BRIDGE_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	return deployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgeL1 as any).tags = ["LancaCanonicalBridgeL1"];

export default deployLancaCanonicalBridgeL1;
export { deployLancaCanonicalBridgeL1 };
