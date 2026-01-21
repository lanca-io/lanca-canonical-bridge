import {
	compileContracts,
	createViemChain,
	err,
	ethersSignerCallContract,
	genericDeploy,
	getClients,
	getEnvVar,
	getFallbackClients,
	getNetworkEnvKey,
	getTestClient,
	getTrezorDeployEnabled,
	localhostViemChain,
	log,
	warn,
} from "@concero/contract-utils";

import { getEnvAddress } from "./createEnvAddressGetter";
import { updateEnvAddress, updateEnvVariable } from "./createEnvUpdater";

export {
	compileContracts,
	err,
	ethersSignerCallContract,
	genericDeploy,
	getClients,
	getEnvVar,
	getFallbackClients,
	getNetworkEnvKey,
	getTestClient,
	getTrezorDeployEnabled,
	log,
	warn,
	createViemChain,
	localhostViemChain,
	getEnvAddress,
	updateEnvAddress,
	updateEnvVariable,
};

export { getWallet, getViemAccount } from "./createViemAccountAndWalletGetter";
export { configureDotEnv } from "./configureDotEnv";
