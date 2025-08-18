import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { envPrefixes } from "../../constants";
import { deployLancaCanonicalBridgePool } from "../../deploy/LancaCanonicalBridgePool";
import { deployLancaCanonicalBridgePoolProxy } from "../../deploy/LancaCanonicalBridgePoolProxy";
import { deployProxyAdmin } from "../../deploy/ProxyAdmin";
import { compileContracts } from "../../utils";
import { addDstBridge, addPool, setRateLimits, upgradeLancaPoolProxyImplementation } from "../utils";

async function deployPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridgePool(hre, taskArgs.dstchain);
	}

	if (taskArgs.proxy) {
		await deployProxyAdmin(
			hre,
			envPrefixes.lcBridgePoolProxyAdmin,
			taskArgs.owner,
			taskArgs.dstchain,
		);
		await deployLancaCanonicalBridgePoolProxy(hre, taskArgs.dstchain);
	}

	if (taskArgs.implementation) {
		await upgradeLancaPoolProxyImplementation(hre, taskArgs.dstchain);
	}

	if (taskArgs.vars) {
		await addPool(hre, taskArgs.dstchain);
		await setRateLimits(hre.network.name, taskArgs.dstchain);
		await addDstBridge(hre, taskArgs.dstchain);
	}

	if (taskArgs.pause) {
		await upgradeLancaPoolProxyImplementation(hre, taskArgs.dstchain, true);
	}
}

// yarn hardhat deploy-pool [--implementation] [--proxy] [--addpool] [--pause] [--owner <address>] --chain <chain_name> --network <network_name>
task("deploy-pool", "Deploy LancaCanonicalBridgePool with proxy")
	.addFlag("implementation", "Deploy pool implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin for pool")
	.addFlag("vars", "Set rate limits and add pool to L1 Bridge contract")
	.addFlag("pause", "Pause pool")
	.addOptionalParam("owner", "Override proxy admin owner address")
	.addParam("dstchain", "Destination chain name for the pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployPoolTask(taskArgs, hre);
	});

export { deployPoolTask };
