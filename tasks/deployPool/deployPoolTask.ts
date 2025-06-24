import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum } from "../../constants";
import { deployLancaCanonicalBridgePool } from "../../deploy/LancaCanonicalBridgePool";
import { deployLancaCanonicalBridgePoolProxy } from "../../deploy/LancaCanonicalBridgePoolProxy";
import { deployLancaCanonicalBridgePoolProxyAdmin } from "../../deploy/LancaCanonicalBridgePoolProxyAdmin";
import { compileContracts } from "../../utils";
import { addPool, upgradeLancaProxyImplementation } from "../utils";

async function deployPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridgePool(hre);
	}

	if (taskArgs.proxy) {
		await deployLancaCanonicalBridgePoolProxyAdmin(hre);
		await deployLancaCanonicalBridgePoolProxy(hre);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgePoolProxy, false);
	}

	if (taskArgs.addpool) {
		await addPool(hre, taskArgs.chainid);
	}
}

task("deploy-pool", "Deploy LancaCanonicalBridgePool with proxy")
	.addFlag("implementation", "Deploy pool implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin for pool")
	.addFlag("addpool", "Add pool to L1 Bridge contract")
	.addParam("chainid", "Destination chain id for the pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployPoolTask(taskArgs, hre);
	});

export { deployPoolTask };
