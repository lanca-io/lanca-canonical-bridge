import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { deployFiatToken } from "../../deploy/FiatToken";
import { deployFiatTokenProxy } from "../../deploy/FiatTokenProxy";
import { deployFiatTokenProxyAdmin } from "../../deploy/FiatTokenProxyAdmin";
import { configureFiatToken } from "../utils/configureFiatToken";
import { initializeDefaultFiatToken } from "../utils/initializeDefaultFiatToken";
import { initializeFiatToken } from "../utils/initializeFiatToken";

async function deployFiatTokenTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	if (taskArgs.implementation) {
		await deployFiatToken(hre);
		await initializeDefaultFiatToken(hre);
	}

	if (taskArgs.proxy) {
		await deployFiatTokenProxyAdmin(hre);
		await deployFiatTokenProxy(hre);
	}

	if (taskArgs.implementation) {
		await initializeFiatToken(hre);
	}

    if (taskArgs.settings) {
		await configureFiatToken(hre);
	}
}

task("deploy-fiat-token", "Deploy FiatToken")
	.addFlag("implementation", "Deploy implementation")
	.addFlag("proxy", "Deploy proxy")
	.addFlag("settings", "Configure FiatToken")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployFiatTokenTask(taskArgs, hre);
	});

export { deployFiatTokenTask };
