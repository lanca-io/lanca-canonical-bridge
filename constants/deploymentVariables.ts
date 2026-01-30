import { WriteContractParameters } from "viem";
import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";

import { ConceroNetwork } from "../types/ConceroNetwork";
import { EnvPrefixes } from "../types/deploymentVariables";

enum ProxyEnum {
	lcBridgeProxy = "lcBridgeProxy",
	lcBridgePoolProxy = "lcBridgePoolProxy",
}

const viemReceiptConfig: WaitForTransactionReceiptParameters = {
	timeout: 0,
	confirmations: 2,
};

const writeContractConfig: WriteContractParameters = {
	gas: 3000000n, // 3M
};

const defaultRateLimits = {
	outMax: "10000000",
	outRefill: "1000000",
	inMax: "10000000",
	inRefill: "1000000",
};

const defaultMinterAllowedAmount = 1000000e6;

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
const EMPTY_BYTES = "0x0000000000000000000000000000000000000000000000000000000000000000";
const ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

function getViemReceiptConfig(chain: ConceroNetwork): Partial<WaitForTransactionReceiptParameters> {
	return {
		timeout: 0,
		confirmations: chain.confirmations,
	};
}

const envPrefixes: EnvPrefixes = {
	lcBridge: "LC_BRIDGE",
	lcBridgeProxy: "LC_BRIDGE_PROXY",
	lcBridgeProxyAdmin: "LC_BRIDGE_PROXY_ADMIN",
	lcBridgePool: "LC_BRIDGE_POOL",
	lcBridgePoolProxy: "LC_BRIDGE_POOL_PROXY",
	lcBridgePoolProxyAdmin: "LC_BRIDGE_POOL_PROXY_ADMIN",
	pause: "CONCERO_PAUSE",
};

export {
	viemReceiptConfig,
	writeContractConfig,
	ProxyEnum,
	envPrefixes,
	getViemReceiptConfig,
	defaultRateLimits,
	defaultMinterAllowedAmount,
	ADDRESS_ZERO,
	EMPTY_BYTES,
	ADMIN_SLOT,
};
