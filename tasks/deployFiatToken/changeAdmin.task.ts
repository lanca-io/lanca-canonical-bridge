import { task } from "hardhat/config";
import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { fiatTokenChangeAdmin } from "../utils/fiatTokenChangeAdmin";

task("fiat-token-change-admin", "Fiat token change admin")
	.addParam("admin", "New admin address")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await fiatTokenChangeAdmin(hre, taskArgs.admin);
	});

export default {};
