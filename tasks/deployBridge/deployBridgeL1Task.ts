import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum, envPrefixes } from "../../constants";
import { deployLancaCanonicalBridgeL1 } from "../../deploy/LancaCanonicalBridgeL1";
import { deployLancaCanonicalBridgeProxy } from "../../deploy/LancaCanonicalBridgeProxy";
import { deployProxyAdmin } from "../../deploy/ProxyAdmin";
import { compileContracts } from "../../utils";
import { upgradeLancaProxyImplementation } from "../utils";

async function deployBridgeL1Task(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridgeL1(hre);
	}

	if (taskArgs.proxy) {
		await deployProxyAdmin(hre, envPrefixes.lcBridgeProxyAdmin, taskArgs.owner);
		await deployLancaCanonicalBridgeProxy(hre, ProxyEnum.lcBridgeProxy);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, false);
	}

	if (taskArgs.pause) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, true);
	}
}

// yarn hardhat deploy-bridge-l1 [--implementation] [--proxy] [--pause] [--owner <address>] --network <network_name>
task("deploy-bridge-l1", "Deploy LancaCanonicalBridge L1 components")
	.addFlag("implementation", "Deploy L1 bridge implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin")
	.addOptionalParam("owner", "Override proxy admin owner address")
	.addFlag("pause", "Pause L1 bridge")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployBridgeL1Task(taskArgs, hre);
	});

export { deployBridgeL1Task };
