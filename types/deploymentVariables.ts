import { ProxyEnum } from "../constants";

export type IProxyType = keyof typeof ProxyEnum;

type ProxyEnvPrefixes = {
	[key in ProxyEnum]: string;
};
export type EnvPrefixes = {
	lcBridge: string;
	lcBridgeProxy: string;
	lcBridgeProxyAdmin: string;
	lcBridgePool: string;
	lcBridgePoolProxy: string;
	lcBridgePoolProxyAdmin: string;
	pause: string;
};
/**
 * Update an environment variable in the .env file
 * @param key The key of the environment variable to update
 * @param newValue The new value of the environment variable
 * @param envFileName The name of the .env file to update
 * usage: // updateEnvVariable("CLF_DON_SECRETS_VERSION_SEPOLIA", "1712841283", "../../../.env.clf");
 */
export type EnvFileName =
	| "deployments.mainnet"
	| "deployments.testnet"
	| "deployments.localhost"
	| "tokens";
