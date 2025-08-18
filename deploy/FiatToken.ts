import { getNetworkEnvKey } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { log, updateEnvVariable } from "../utils";

const deployFiatToken = async function (hre: HardhatRuntimeEnvironment): Promise<Deployment> {
	const { deployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const chain = conceroNetworks[name];
	const { type: networkType } = chain;

	log(`Deploying FiatToken implementation:`, "deployFiatToken", name);


	const signatureCheckerDeployment = await deploy("SignatureChecker", {
		from: deployer,
		args: [],
		log: true,
		autoMine: true,
	});

	const deployment = await deploy("FiatTokenV2_2", {
		from: deployer,
		libraries: {
			SignatureChecker: signatureCheckerDeployment.address,
		},
		args: [],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address} \n`, "deployFiatToken", name);

	updateEnvVariable(
		`FIAT_TOKEN_IMPLEMENTATION_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}`,
	);

	if (hre.network.live) {
		try {
			log("Verifying FiatTokenV2_2 contract...", "deployFiatToken", name);
			await hre.run("verify:verify", {
				address: deployment.address,
				constructorArguments: [],
				libraries: {
					SignatureChecker: signatureCheckerDeployment.address,
				},
			});
		} catch (error) {
			log(`Verification failed: ${error}`, "deployFiatToken", name);
		}
	}

	return deployment;
};

(deployFiatToken as any).tags = ["FiatToken"];

export default deployFiatToken;
export { deployFiatToken };
