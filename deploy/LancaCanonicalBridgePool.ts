import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

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
	const { name: srcChainName } = hre.network;

	const srcChain = conceroNetworks[srcChainName];
	const { type: networkType} = srcChain;

	const dstChain = conceroNetworks[dstChainName];

	if (!dstChain) {
		throw new Error(`Destination chain ${dstChainName} not found.`);
	}

	const lancaCanonicalBridgeAddress = getEnvVar(
		`LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)}`,
	);

	if (!lancaCanonicalBridgeAddress) {
		throw new Error(
			`LancaCanonicalBridge address not found. Set LANCA_CANONICAL_BRIDGE_PROXY_${getNetworkEnvKey(srcChainName)} in environment variables.`,
		);
	}

	const usdcAddress = getEnvVar(`FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChainName)}`);
	if (!usdcAddress) {
		throw new Error(
			`USDC address not found. Set FIAT_TOKEN_PROXY_${getNetworkEnvKey(srcChainName)} in environment variables.`,
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

	log(`Deploying LancaCanonicalBridgePool with args:`, "deployLancaCanonicalBridgePool", srcChainName);
	log(`  usdcAddress: ${args.usdcAddress}`, "deployLancaCanonicalBridgePool", srcChainName);
	log(
		`  lancaCanonicalBridgeAddress: ${args.lancaCanonicalBridgeAddress}`,
		"deployLancaCanonicalBridgePool",
		srcChainName,
	);
	log(`  dstChainSelector: ${args.dstChainSelector}`, "deployLancaCanonicalBridgePool", srcChainName);

	const deployment = await deploy("LancaCanonicalBridgePool", {
		from: deployer,
		args: [args.usdcAddress, args.lancaCanonicalBridgeAddress, args.dstChainSelector],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployLancaCanonicalBridgePool", srcChainName);

	updateEnvVariable(
		`LC_BRIDGE_POOL_${getNetworkEnvKey(srcChainName)}_${getNetworkEnvKey(dstChain.name)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	return deployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgePool as any).tags = ["LancaCanonicalBridgePool"];

export default deployLancaCanonicalBridgePool;
export { deployLancaCanonicalBridgePool };
