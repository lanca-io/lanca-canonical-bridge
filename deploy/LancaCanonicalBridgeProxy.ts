import { getNetworkEnvKey, hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { encodeFunctionData, keccak256 } from "viem";

import { accessControlAbi, conceroNetworks, getViemReceiptConfig, proxyAbi } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { IProxyType } from "../types/deploymentVariables";
import {
	err,
	getEnvAddress,
	getEnvVar,
	getFallbackClients,
	getViemAccount,
	log,
	updateEnvAddress,
} from "../utils";

type DeploymentFunction = (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
) => Promise<Deployment>;

const deployLancaCanonicalBridgeProxy: DeploymentFunction = async function (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
): Promise<Deployment> {
	const { name } = hre.network;
	const chain = conceroNetworks[name];
	const { type } = chain;

	const [initialImplementation, initialImplementationAlias] = getEnvAddress("lcBridge", name);
	const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, name);

	const viemAccount = getViemAccount(type, "proxyDeployer");
	const { publicClient, walletClient } = getFallbackClients(chain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[name];
	if (config) {
		gasLimit = config.proxy?.gasLimit || 0;
	}

	const adminAddress = viemAccount.address;
	const initializeData = encodeFunctionData({
		abi: proxyAbi,
		functionName: "initialize",
		args: [adminAddress],
	});

	const lancaProxyDeployment = await hardhatDeployWrapper("LCBTransparentUpgradeableProxy", {
		hre,
		args: [initialImplementation, proxyAdmin, initializeData],
		publicClient,
		proxy: true,
		gasLimit,
	});

	log(
		`Deployed at: ${lancaProxyDeployment.address}. 
		 Initial impl: ${initialImplementationAlias}, 
		 Proxy admin: ${proxyAdminAlias},
		 Hash: ${lancaProxyDeployment.transactionHash}, 
		 Initialize data: ${initializeData}`,
		`deployLancaCanonicalBridgeProxy: ${proxyType}`,
		name,
	);

	updateEnvAddress(proxyType, name, lancaProxyDeployment.address, `deployments.${type}`);

	const rateLimitAdmin = getEnvVar(`TESTNET_RATE_LIMIT_ADMIN_ADDRESS`);
	if (!rateLimitAdmin) {
		err(
			`Rate limit admin address not found. Set ${getNetworkEnvKey(type)}_RATE_LIMIT_ADMIN_ADDRESS in environment variables.`,
			"deployLancaCanonicalBridge",
			name,
		);
	}

	const RATE_LIMIT_ADMIN_ROLE = keccak256("RATE_LIMIT_ADMIN");

	const isRateLimitAdmin = await publicClient.readContract({
		address: lancaProxyDeployment.address,
		abi: accessControlAbi,
		functionName: "hasRole",
		args: [RATE_LIMIT_ADMIN_ROLE, rateLimitAdmin],
	});

	if (isRateLimitAdmin) {
		log(
			`Rate limit admin role already granted to ${rateLimitAdmin}`,
			`deployLancaCanonicalBridgeProxy: ${proxyType}`,
			name,
		);
		return lancaProxyDeployment;
	}

	const txHash = await walletClient.writeContract({
		address: lancaProxyDeployment.address,
		abi: accessControlAbi,
		functionName: "grantRole",
		args: [RATE_LIMIT_ADMIN_ROLE, rateLimitAdmin],
		account: viemAccount,
		chain: chain.viemChain,
	});

	const { transactionHash } = await publicClient.waitForTransactionReceipt({
		...getViemReceiptConfig(chain),
		hash: txHash,
	});

	log(
		`Granted rate limit admin role to ${rateLimitAdmin}. Hash: ${transactionHash}`,
		`deployLancaCanonicalBridgeProxy: ${proxyType}`,
		name,
	);

	return lancaProxyDeployment;
};

// Assign tags to the function
(deployLancaCanonicalBridgeProxy as any).tags = ["LancaCanonicalBridgeProxy"];

export { deployLancaCanonicalBridgeProxy };
