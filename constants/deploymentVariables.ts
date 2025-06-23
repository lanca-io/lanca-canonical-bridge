import { WriteContractParameters } from "viem";
import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";

import { ConceroNetwork } from "../types/ConceroNetwork";
import { EnvPrefixes } from "../types/deploymentVariables";

enum ProxyEnum {
	lcBridgeProxy = "lcBridgeProxy",
}

const viemReceiptConfig: WaitForTransactionReceiptParameters = {
	timeout: 0,
	confirmations: 2,
};

const writeContractConfig: WriteContractParameters = {
	gas: 3000000n, // 3M
};

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
	pause: "LANCA_CANONICAL_BRIDGE_PAUSE",
};

export { viemReceiptConfig, writeContractConfig, ProxyEnum, envPrefixes, getViemReceiptConfig };
