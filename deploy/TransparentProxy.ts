import { hardhatDeployWrapper } from "@concero/contract-utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Hex } from "viem";

import { ADMIN_SLOT, ProxyEnum, conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { EnvFileName, EnvPrefixes, IProxyType } from "../types/deploymentVariables";
import { getEnvAddress, getFallbackClients, getViemAccount, log, updateEnvAddress } from "../utils";

export const deployTransparentProxy: (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
	callData?: Hex,
	dstChainName?: string,
) => Promise<void> = async (
	hre: HardhatRuntimeEnvironment,
	proxyType: IProxyType,
	callData?: Hex,
	dstChainName?: string,
) => {
	const { name: srcChainName } = hre.network;
	const [deployer] = await hre.ethers.getSigners();

	const srcChain = conceroNetworks[srcChainName as keyof typeof conceroNetworks];
	const { type } = srcChain;

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

	const [initialImplementation, initialImplementationAlias] = getEnvAddress(
		implementationKey,
		envChainName,
	);

	const viemAccount = getViemAccount(type, "deployer");
	const { publicClient } = getFallbackClients(srcChain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[srcChainName];
	if (config?.proxy) {
		gasLimit = config.proxy.gasLimit;
	}

	const proxyDeployment = await hardhatDeployWrapper("TransparentUpgradeableProxy", {
		hre,
		args: [initialImplementation, deployer.address, callData ?? "0x"],
		publicClient,
		gasLimit,
		log: true
	});

	updateEnvAddress(
		proxyType,
		envChainName,
		proxyDeployment.address,
		`deployments.${type}` as EnvFileName,
	);

	const proxyAdminBytes = await publicClient.getStorageAt({
		address: proxyDeployment.address as Hex,
		slot: ADMIN_SLOT as Hex,
	});

	const proxyAdminAddress = `0x${proxyAdminBytes!.slice(-40)}` as Hex;

	log(
		`Deployed at: ${proxyDeployment.address}. 
		 Initial impl: ${initialImplementationAlias}, 
		 Proxy admin: ${proxyAdminAddress},
		 Hash: ${proxyDeployment.transactionHash}, 
		 Initialize data: ${callData}`,
		`Proxy type: ${proxyType}`,
		envChainName,
	);

	updateEnvAddress(`${proxyType}Admin`, envChainName, proxyAdminAddress, `deployments.${type}`);
};
