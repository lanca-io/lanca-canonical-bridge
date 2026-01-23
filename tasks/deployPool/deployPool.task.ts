import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum } from "../../constants";
import { deployLancaCanonicalBridgePool } from "../../deploy/LancaCanonicalBridgePool";
import { deployTransparentProxy } from "../../deploy/TransparentProxy";
import { compileContracts } from "../../utils";
import {
	addDstBridge,
	addPool,
	setLibs,
	setRateLimits,
	upgradeLancaProxyImplementation,
} from "../utils";

async function deployPoolTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridgePool(hre, taskArgs.dstchain);
	}

	if (taskArgs.proxy) {
		await deployTransparentProxy(hre, ProxyEnum.lcBridgePoolProxy, "0x", taskArgs.dstchain);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(
			hre,
			ProxyEnum.lcBridgePoolProxy,
			false,
			taskArgs.dstchain,
		);
	}

	if (taskArgs.vars) {
		await addPool(taskArgs.dstchain);
		await addDstBridge(taskArgs.dstchain);
		await setRateLimits(hre.network.name, taskArgs.dstchain);
		await setLibs(hre.network.name);
	}

	if (taskArgs.pause) {
		await upgradeLancaProxyImplementation(
			hre,
			ProxyEnum.lcBridgePoolProxy,
			true,
			taskArgs.dstchain,
		);
	}
}

// yarn hardhat deploy-pool --implementation --proxy --vars --network ethereumSepolia --dstchain <network_name>
task("deploy-pool", "Deploy LancaCanonicalBridgePool with proxy")
	.addFlag("implementation", "Deploy pool implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin for pool")
	.addFlag("vars", "Set variables")
	.addFlag("pause", "Pause pool")
	.addOptionalParam("owner", "Override proxy admin owner address")
	.addParam("dstchain", "Destination chain name for the pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployPoolTask(taskArgs, hre);
	});

export { deployPoolTask };
