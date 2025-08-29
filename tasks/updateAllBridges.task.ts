import { task } from "hardhat/config";

import { execSync } from "child_process";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { getEnvVar } from "../utils";

task("update-all-bridge-implementations")
	.addParam("l1chain", "L1 chain name")
	.setAction(async (taskArgs, hre) => {
		for (const network in conceroNetworks) {
			if (network === taskArgs.l1chain) continue;
			if (getEnvVar(`LANCA_CANONICAL_BRIDGE_${getNetworkEnvKey(network)}`)) {
				console.log(`Updating bridge implementation for ${network}`);
				execSync(`yarn hardhat deploy-bridge --implementation --network ${network}`, {
					encoding: "utf8",
					stdio: "inherit",
				});
			}
		}
	});

export default {};
