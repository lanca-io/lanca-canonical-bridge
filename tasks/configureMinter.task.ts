import { configureMinter } from "./utils/configureMinter";
import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

async function configureMinterTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	await configureMinter(hre.network.name, taskArgs.amount);
}

// yarn hardhat configure-minter --network <network_name>
task("configure-minter", "Configure Minter")
	.addOptionalParam("amount", "Amount of USDC to allow for minter")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await configureMinterTask(taskArgs, hre);
	});

export { configureMinterTask };
