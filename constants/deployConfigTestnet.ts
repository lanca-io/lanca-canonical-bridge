type DeployConfigTestnet = {
	[key: string]: {
		priceFeed?: {
			gasLimit: number;
		};
		usdc?: {
			gasLimit: number;
		};
		proxyAdmin?: {
			gasLimit: number;
		};
		proxy?: {
			gasLimit: number;
		};
	};
};

export const DEPLOY_CONFIG_TESTNET: DeployConfigTestnet = {
	inkSepolia: {
		priceFeed: {
			gasLimit: 1000000,
		},
		usdc: {
			gasLimit: 1000000,
		},
		proxyAdmin: {
			gasLimit: 500000,
		},
		proxy: {
			gasLimit: 500000,
		},
	},
	b2Testnet: {
		priceFeed: {
			gasLimit: 1000000,
		},
		usdc: {
			gasLimit: 1000000,
		},
		proxyAdmin: {
			gasLimit: 500000,
		},
		proxy: {
			gasLimit: 500000,
		},
	},
	seismicDevnet: {
		priceFeed: {
			gasLimit: 500000,
		},
		usdc: {
			gasLimit: 1000000,
		},
		proxyAdmin: {
			gasLimit: 500000,
		},
		proxy: {
			gasLimit: 500000,
		},
	},
};
