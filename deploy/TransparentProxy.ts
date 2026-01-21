import { IDeployResult, genericDeploy } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Hex } from "viem";

import { ProxyEnum } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { EnvFileName, EnvPrefixes, IProxyType } from "../types/deploymentVariables";
import { getEnvAddress, log, updateEnvAddress } from "../utils";

export const deployTransparentProxy = async (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
	callData?: Hex,
	dstChainName?: string,
): Promise<IDeployResult> => {
	const { name: srcChainName } = hre.network;
	const [deployer] = await hre.ethers.getSigners();

	let implementationKey: keyof EnvPrefixes;
	let envChainName: string;
	if (proxyType === ProxyEnum.lcBridgeProxy) {
		implementationKey = "lcBridge";
		envChainName = srcChainName;
	} else if (proxyType === ProxyEnum.lcBridgePoolProxy) {
		implementationKey = "lcBridgePool";
		envChainName = dstChainName || "";
	} else {
		throw new Error(`Proxy type ${proxyType} not found`);
	}

	const [initialImplementation] = getEnvAddress(implementationKey, envChainName);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config?.proxy) {
		gasLimit = config.proxy.gasLimit;
	}

	const deployment = await genericDeploy(
		{
			hre,
			contractName: "TransparentUpgradeableProxy",
			txParams: {
				gasLimit: BigInt(gasLimit),
			},
		},
		initialImplementation,
		deployer.address,
		callData ?? "0x",
	);

	updateEnvAddress(
		proxyType,
		deployment.address,
		`deployments.${deployment.chainType}` as EnvFileName,
		envChainName,
	);

	log(
		`Deployed at: ${deployment.proxyAdminAddress}. initialOwner: ${deployer.address}`,
		`deployProxyAdmin: ${proxyType}`,
		deployment.chainName,
	);

	updateEnvAddress(
		`${proxyType}Admin`,
		deployment.proxyAdminAddress as Hex,
		`deployments.${deployment.chainType}` as EnvFileName,
		envChainName,
	);

	return deployment;
};
