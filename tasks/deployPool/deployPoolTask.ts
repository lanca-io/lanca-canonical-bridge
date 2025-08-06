import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { envPrefixes } from "../../constants";
import { deployLancaCanonicalBridgePool } from "../../deploy/LancaCanonicalBridgePool";
import { deployLancaCanonicalBridgePoolProxy } from "../../deploy/LancaCanonicalBridgePoolProxy";
import { deployProxyAdmin } from "../../deploy/ProxyAdmin";
import { compileContracts } from "../../utils";
import { addPool, upgradeLancaPoolProxyImplementation } from "../utils";

async function deployPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridgePool(hre, taskArgs.chain);
	}

	if (taskArgs.proxy) {
		await deployProxyAdmin(
			hre,
			envPrefixes.lcBridgePoolProxyAdmin,
			taskArgs.owner,
			taskArgs.chain,
		);
		await deployLancaCanonicalBridgePoolProxy(hre, taskArgs.chain);
	}

	if (taskArgs.implementation) {
		await upgradeLancaPoolProxyImplementation(hre, taskArgs.chain);
	}

	if (taskArgs.addpool) {
		await addPool(hre, taskArgs.chain);
	}

	if (taskArgs.pause) {
		await upgradeLancaPoolProxyImplementation(hre, taskArgs.chain, true);
	}
}

// yarn hardhat deploy-pool [--implementation] [--proxy] [--addpool] [--pause] [--owner <address>] --chain <chain_name> --network <network_name>
task("deploy-pool", "Deploy LancaCanonicalBridgePool with proxy")
	.addFlag("implementation", "Deploy pool implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin for pool")
	.addFlag("addpool", "Add pool to L1 Bridge contract")
	.addFlag("pause", "Pause pool")
	.addOptionalParam("owner", "Override proxy admin owner address")
	.addParam("chain", "Destination chain name for the pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployPoolTask(taskArgs, hre);
	});

export { deployPoolTask };
