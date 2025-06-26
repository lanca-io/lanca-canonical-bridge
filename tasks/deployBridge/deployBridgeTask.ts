import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { ProxyEnum } from "../../constants";
import { deployLancaCanonicalBridge } from "../../deploy/LancaCanonicalBridge";
import { deployLancaCanonicalBridgeProxy } from "../../deploy/LancaCanonicalBridgeProxy";
import { deployLancaCanonicalBridgeProxyAdmin } from "../../deploy/LancaCanonicalBridgeProxyAdmin";
import { compileContracts } from "../../utils";
import { upgradeLancaProxyImplementation } from "../utils";

async function deployBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridge(hre, taskArgs.chain);
	}

	if (taskArgs.proxy) {
		await deployLancaCanonicalBridgeProxyAdmin(hre, ProxyEnum.lcBridgeProxy);
		await deployLancaCanonicalBridgeProxy(hre, ProxyEnum.lcBridgeProxy);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, false);
	}

	if (taskArgs.pause) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, true);
	}
}

// yarn hardhat deploy-bridge [--implementation] [--proxy] [--pause] --chain <chain_name> --network <network_name>
task("deploy-bridge", "Deploy LancaCanonicalBridge")
	.addFlag("implementation", "Deploy implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin")
	.addFlag("pause", "Pause bridge")
	.addParam("chain", "Destination chain name (L1)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployBridgeTask(taskArgs, hre);
	});

export { deployBridgeTask };
