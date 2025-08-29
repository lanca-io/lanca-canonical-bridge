import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { fiatTokenChangeAdmin } from "./utils/fiatTokenChangeAdmin";

// yarn hardhat fiat-token-change-admin --admin <address>
task("fiat-token-change-admin", "Fiat token change admin")
	.addParam("admin", "New admin address")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await fiatTokenChangeAdmin(hre.network.name, taskArgs.admin);
	});

export default {};
