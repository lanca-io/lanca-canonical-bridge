type DeployConfigTestnet = {
	[key: string]: {
		pool?: {
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
		pool: {
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
		pool: {
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
		pool: {
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
