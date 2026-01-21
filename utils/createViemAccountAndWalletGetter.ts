import {
	baseAccountTypePrefixes,
	createViemAccountGetter,
	createWalletGetter,
} from "@concero/contract-utils";

const customPrefixes = {
	...baseAccountTypePrefixes,
	rateLimitAdmin: "RATE_LIMIT_ADMIN",
	rebalancer: "REBALANCER",
} as const;

export const { getWallet } = createWalletGetter({
	accountTypePrefixes: customPrefixes,
});

export const { getViemAccount } = createViemAccountGetter({
	accountTypePrefixes: customPrefixes,
	getWallet,
});
