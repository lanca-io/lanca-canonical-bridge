import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { envPrefixes } from "../../constants";
import { changeProxyAdminOwner } from "../utils/changeProxyAdminOwner";

async function changeProxyAdminOwnerTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	const { type, newowner, chain } = taskArgs;

	let envPrefix: string;
	let dstChainName: string | undefined;

	switch (type) {
		case "bridge":
			envPrefix = envPrefixes.lcBridgeProxyAdmin;
			break;
		case "pool":
			envPrefix = envPrefixes.lcBridgePoolProxyAdmin;
			dstChainName = chain;
			if (!dstChainName) {
				throw new Error("--chain parameter is required for pool type");
			}
			break;
		default:
			throw new Error(`Invalid type: ${type}. Valid types are: bridge, pool`);
	}

	await changeProxyAdminOwner(hre, envPrefix, newowner, dstChainName);
}

// yarn hardhat change-proxy-admin-owner --type <bridge|pool> --newowner <address> [--chain <chain_name>] --network <network_name>
task("change-proxy-admin-owner", "Change owner of ProxyAdmin contract")
	.addParam("type", "Type of ProxyAdmin (bridge, pool)")
	.addParam("newowner", "New owner address")
	.addOptionalParam("chain", "Destination chain name (required for pool type)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await changeProxyAdminOwnerTask(taskArgs, hre);
	});

export { changeProxyAdminOwnerTask };
