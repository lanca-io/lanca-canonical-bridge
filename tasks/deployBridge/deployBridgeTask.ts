import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { deployLancaCanonicalBridge } from "../../deploy";
import { compileContracts } from "../../utils";

async function deployBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridge(hre);
	}

	// TODO: Proxy support can be added later if needed
	// if (taskArgs.proxy) {
	// 	console.log("Proxy deployment not implemented yet");
	// }
}

task("deploy-bridge", "Deploy LancaCanonicalBridge")
	.addFlag("implementation", "Deploy implementation")
	.addFlag("proxy", "Deploy proxy (not implemented yet)")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployBridgeTask(taskArgs, hre);
	});

export { deployBridgeTask };
