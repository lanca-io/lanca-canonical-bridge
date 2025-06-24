import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum } from "../../constants";
import { deployLancaCanonicalBridge } from "../../deploy/LancaCanonicalBridge";
import { deployLancaCanonicalBridgeProxy } from "../../deploy/LancaCanonicalBridgeProxy";
import { deployLancaCanonicalBridgeProxyAdmin } from "../../deploy/LancaCanonicalBridgeProxyAdmin";
import { deployLancaCanonicalBridgePool } from "../../deploy/LancaCanonicalBridgePool";
import { compileContracts } from "../../utils";
import { upgradeLancaProxyImplementation } from "../utils";

async function deployBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridge(hre);
	}

	if (taskArgs.proxy) {
		await deployLancaCanonicalBridgeProxyAdmin(hre, ProxyEnum.lcBridgeProxy);
		await deployLancaCanonicalBridgeProxy(hre, ProxyEnum.lcBridgeProxy);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, false);
	}

	if (taskArgs.pool) {
		await deployLancaCanonicalBridgePool(hre);
	}
}

task("deploy-bridge", "Deploy LancaCanonicalBridge")
	.addFlag("implementation", "Deploy implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin")
	.addFlag("pool", "Deploy pool")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployBridgeTask(taskArgs, hre);
	});

export { deployBridgeTask };
