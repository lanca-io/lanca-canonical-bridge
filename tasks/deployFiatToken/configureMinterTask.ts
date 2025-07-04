import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { configureMinter } from "../utils/configureMinter";
import { configureMinterTest } from "../utils/configureMinterTest";

async function configureMinterTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
    if (taskArgs.bridge) {
        await configureMinter(hre);
    }

    if (taskArgs.test) {
        await configureMinterTest(hre);
    }
}

// yarn hardhat configure-minter [--bridge] [--test] --network <network_name>
task("configure-minter", "Configure Minter")
    .addFlag("bridge", "Configure Minter for bridge")
    .addFlag("test", "Configure Minter for test")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await configureMinterTask(taskArgs, hre);
	});

export { configureMinterTask };