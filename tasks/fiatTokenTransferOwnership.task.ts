import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";

import { fiatTokenTransferOwnership } from "./utils/fiatTokenTransferOwnership";

task("fiat-token-transfer-ownership", "Fiat token transfer ownership")
	.addParam("owner", "New owner address")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await fiatTokenTransferOwnership(hre.network.name, taskArgs.owner);
	});

export default {};
