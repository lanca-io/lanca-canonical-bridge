import type { ConceroNetwork } from "@concero/contract-utils";
import { WriteContractParameters } from "viem";
import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";

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

function getViemReceiptConfig(chain: ConceroNetwork): Partial<WaitForTransactionReceiptParameters> {
	return {
		timeout: 0,
		confirmations: chain.confirmations,
	};
}

export {
	viemReceiptConfig,
	writeContractConfig,
	ProxyEnum,
	getViemReceiptConfig,
	defaultRateLimits,
	defaultMinterAllowedAmount,
	ADDRESS_ZERO,
	EMPTY_BYTES,
};
