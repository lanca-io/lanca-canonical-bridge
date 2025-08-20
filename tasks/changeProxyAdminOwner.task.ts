import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { envPrefixes } from "../constants";
import { changeProxyAdminOwner } from "./utils/changeProxyAdminOwner";
import { err } from "../utils";

async function changeProxyAdminOwnerTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	const { type, newowner, dstchain } = taskArgs;

	let envPrefix: string;
	let dstChainName: string | undefined;

	switch (type) {
		case "bridge":
			envPrefix = envPrefixes.lcBridgeProxyAdmin;
			break;
		case "pool":
			envPrefix = envPrefixes.lcBridgePoolProxyAdmin;
			dstChainName = dstchain;
			if (!dstChainName) {
				err(`dstchain parameter is required for pool type`, "changeProxyAdminOwnerTask", hre.network.name);
				return;
			}
			break;
		default:
			err(`Invalid type: ${type}. Valid types are: bridge, pool`, "changeProxyAdminOwnerTask", hre.network.name);
			return;
	}

	await changeProxyAdminOwner(hre.network.name, envPrefix, newowner, dstChainName);
}

// yarn hardhat change-proxy-admin-owner --type <bridge|pool> --newowner <address> [--dstchain <chain_name>] --network <network_name>
task("change-proxy-admin-owner", "Change owner of ProxyAdmin contract")
	.addParam("type", "Type of ProxyAdmin (bridge, pool)")
	.addParam("newowner", "New owner address")
	.addOptionalParam("dstchain", "Destination chain name (required for pool type)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await changeProxyAdminOwnerTask(taskArgs, hre);
	});

export { changeProxyAdminOwnerTask };
