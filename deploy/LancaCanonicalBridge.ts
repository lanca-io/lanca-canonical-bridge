import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { ConceroNetwork } from "../types/ConceroNetwork";
import { err, getEnvVar, log, updateEnvVariable } from "../utils/";

type DeployArgs = {
	l1ChainSelector?: bigint;
	conceroRouter: string;
	usdcAddress: string;
	l1BridgeAddress?: string;
	rateLimitAdmin: string;
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

		l1BridgeAddress =
			getEnvVar(`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain.name)}`) || "";
		l1ChainSelector = BigInt(dstChain.chainId);
		if (!l1BridgeAddress || !l1ChainSelector) {
			err(
				`L1 Bridge address of L1 chain selector ${l1ChainSelector} not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(dstChain.name)} in .env.deployments.${networkType} variables.`,
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

	const rateLimitAdmin = getEnvVar(`TESTNET_RATE_LIMIT_ADMIN_ADDRESS`);
	if (!rateLimitAdmin) {
		err(
			`Rate limit admin address not found. Set ${getNetworkEnvKey(networkType)}_RATE_LIMIT_ADMIN_ADDRESS in environment variables.`,
			"deployLancaCanonicalBridge",
			name,
		);
	}

	if (!conceroRouter || !usdcAddress || !rateLimitAdmin) {
		return {} as Deployment;
	}

	const defaultArgs: DeployArgs = {
		l1ChainSelector,
		conceroRouter,
		usdcAddress,
		l1BridgeAddress,
		rateLimitAdmin,
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
			args.rateLimitAdmin,
		];

		log(`Deploying LancaCanonicalBridge with args:`, "deployLancaCanonicalBridge", name);
		log(`  l1ChainSelector: ${args.l1ChainSelector}`, "deployLancaCanonicalBridge", name);
		log(`  l1BridgeAddress: ${args.l1BridgeAddress}`, "deployLancaCanonicalBridge", name);
	} else {
		constructorName = "LancaCanonicalBridgeL1";
		constructorArgs = [args.conceroRouter, args.usdcAddress, args.rateLimitAdmin];

		log(`Deploying LancaCanonicalBridgeL1 with args:`, "deployLancaCanonicalBridge", name);
	}
	log(`  conceroRouter: ${args.conceroRouter}`, "deployLancaCanonicalBridge", name);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridge", name);
	log(`  rateLimitAdmin: ${args.rateLimitAdmin}`, "deployLancaCanonicalBridge", name);

	const deployment = await deploy(constructorName, {
		from: deployer,
		args: constructorArgs,
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

(deployLancaCanonicalBridge as any).tags = ["LancaCanonicalBridge"];

export default deployLancaCanonicalBridge;
export { deployLancaCanonicalBridge };
