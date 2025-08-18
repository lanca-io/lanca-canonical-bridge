import fs from "fs";
import path from "path";

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

	// const signatureCheckerArtifactPath = path.resolve(
	// 	__dirname,
	// 	"../usdc-artifacts/SignatureChecker.sol/SignatureChecker.json",
	// );
	// const signatureCheckerArtifact = JSON.parse(
	// 	fs.readFileSync(signatureCheckerArtifactPath, "utf8"),
	// );

	const signatureCheckerDeployment = await deploy("SignatureChecker", {
		from: deployer,
		args: [],
		log: true,
		autoMine: true,
	});

	// const artifactPath = path.resolve(
	// 	__dirname,
	// 	"../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	// );
	// const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

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

	return deployment;
};

(deployFiatToken as any).tags = ["FiatToken"];

export default deployFiatToken;
export { deployFiatToken };
