import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar, getGasParameters, log, updateEnvVariable } from "../utils/";

type DeployArgs = {
    dstChainSelector: bigint;
	conceroRouter: string;
	usdcAddress: string;
    lane: string;
};

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
) => Promise<Deployment>;

const deployLancaCanonicalBridge: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	dstChainName: string,
	overrideArgs?: Partial<DeployArgs>,
): Promise<Deployment> {
	const { deployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const chain = conceroNetworks[name];
    const dstChain = conceroNetworks[dstChainName];
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

    const lane = getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)}`);
    if (!lane) {
        throw new Error(
            `Lane address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChainName)} in environment variables.`,
        );
    }

	const defaultArgs: DeployArgs = {
		dstChainSelector: BigInt(dstChain.chainId),
		conceroRouter: conceroRouterAddress,
		usdcAddress: usdcAddress,
        lane: lane,
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	log(`Deploying LancaCanonicalBridge with args:`, "deployLancaCanonicalBridge", name)
    log(`  dstChainSelector: ${args.dstChainSelector}`, "deployLancaCanonicalBridge", name);
	log(`  conceroRouter: ${args.conceroRouter}`, "deployLancaCanonicalBridge", name);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridge", name);
    log(`  lane: ${args.lane}`, "deployLancaCanonicalBridge", name);

	const deployment = await deploy("LancaCanonicalBridge", {
		from: deployer,
		args: [args.dstChainSelector, args.conceroRouter, args.usdcAddress, args.lane],
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
