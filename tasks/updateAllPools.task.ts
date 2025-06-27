import { execSync } from "child_process";

import { task } from "hardhat/config";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar } from "../utils";

task("update-all-pool-implementations")
	.addParam("l1chain", "L1 chain name")
	.setAction(async (taskArgs, hre) => {
		for (const network in conceroNetworks) {
			const chain = conceroNetworks[network];
			if (
				getEnvVar(
					`LC_BRIDGE_POOL_${getNetworkEnvKey(taskArgs.l1chain)}_${getNetworkEnvKey(chain.name)}`,
				)
			) {
				console.log(`Updating pool implementation for ${network}`);
				execSync(
					`yarn hardhat deploy-pool --implementation --chain ${chain.name} --network ${taskArgs.l1chain}`,
					{
						encoding: "utf8",
						stdio: "inherit",
					},
				);
			}
		}
	});

export default {};
