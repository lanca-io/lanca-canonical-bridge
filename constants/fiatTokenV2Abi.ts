export const fiatTokenV2Abi = [
	{
		inputs: [
			{
				internalType: "address",
				name: "minter",
				type: "address",
			},
			{
				internalType: "uint256",
				name: "minterAllowedAmount",
				type: "uint256",
			},
		],
		name: "configureMinter",
		outputs: [
			{
				internalType: "bool",
				name: "",
				type: "bool",
			},
		],
		stateMutability: "nonpayable",
		type: "function",
	},
	{
		inputs: [
			{
				internalType: "address",
				name: "account",
				type: "address",
			},
		],
		name: "isMinter",
		outputs: [
			{
				internalType: "bool",
				name: "",
				type: "bool",
			},
		],
		stateMutability: "view",
		type: "function",
	},
];
