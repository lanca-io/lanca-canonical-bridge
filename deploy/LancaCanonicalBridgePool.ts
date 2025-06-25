import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar, log, updateEnvVariable } from "../utils/";

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
	const { deployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const chain = conceroNetworks[name];
	const { type: networkType } = chain;
    const dstChain = conceroNetworks[dstChainName];

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_${getNetworkEnvKey(name)}`,
	);

	if (!lancaCanonicalBridgeAddress) {
		throw new Error(
			`LancaCanonicalBridge address not found. Set LANCA_CANONICAL_BRIDGE_${getNetworkEnvKey(name)} in environment variables.`,
		);
	}

	const usdcAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)}`);
    if (!usdcAddress) {
		throw new Error(
			`USDC address not found. Set FIAT_TOKEN_PROXY_${getNetworkEnvKey(name)} in environment variables.`,
		);
	}

	const defaultArgs: DeployArgs = {
		usdcAddress: usdcAddress,
		lancaCanonicalBridgeAddress: lancaCanonicalBridgeAddress,
		dstChainSelector: BigInt(dstChain.chainId),
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	log(`Deploying LancaCanonicalBridgePool with args:`, "deployLancaCanonicalBridgePool", name);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridgePool", name);
	log(
		`  lancaCanonicalBridgeAddress: ${args.lancaCanonicalBridgeAddress}`,
		"deployLancaCanonicalBridgePool",
		name,
	);
	log(`  dstChainSelector: ${args.dstChainSelector}`, "deployLancaCanonicalBridgePool", name);

	const deployment = await deploy("LancaCanonicalBridgePool", {
		from: deployer,
		args: [args.usdcAddress, args.lancaCanonicalBridgeAddress, args.dstChainSelector],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployLancaCanonicalBridgePool", name);

	updateEnvVariable(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(name)}_${getNetworkEnvKey(dstChainName)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	return deployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgePool as any).tags = ["LancaCanonicalBridgePool"];

export default deployLancaCanonicalBridgePool;
export { deployLancaCanonicalBridgePool };