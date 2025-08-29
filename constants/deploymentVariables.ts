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

function getViemReceiptConfig(chain: ConceroNetwork): Partial<WaitForTransactionReceiptParameters> {
	return {
		timeout: 0,
		confirmations: chain.confirmations,
	};
}

const envPrefixes: EnvPrefixes = {
	lcBridge: "LANCA_CANONICAL_BRIDGE",
	lcBridgeProxy: "LANCA_CANONICAL_BRIDGE_PROXY",
	lcBridgeProxyAdmin: "LANCA_CANONICAL_BRIDGE_PROXY_ADMIN",
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
};
