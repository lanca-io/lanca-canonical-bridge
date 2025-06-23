import fs from "fs";
import path from "path";

import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { getNetworkEnvKey } from "@concero/contract-utils";

import { conceroNetworks } from "../constants";
import { log, updateEnvVariable } from "../utils";

type DeployArgs = {
	tokenName: string;
	tokenSymbol: string;
	tokenCurrency: string;
	tokenDecimals: number;
};

const deployFiatToken = async function (
	hre: HardhatRuntimeEnvironment,
	overrideArgs?: Partial<DeployArgs>,
): Promise<Deployment> {
	const { deployer } = await hre.getNamedAccounts();
	const { deploy } = hre.deployments;
	const { name } = hre.network;

	const chain = conceroNetworks[name];
	const { type: networkType } = chain;

	const defaultArgs: DeployArgs = {
		tokenName: "USD Coin",
		tokenSymbol: "USDC.e",
		tokenCurrency: "USD",
		tokenDecimals: 6,
	};

	const args: DeployArgs = {
		...defaultArgs,
		...overrideArgs,
	};

	log(`Deploying FiatToken with parameters:`, "deployFiatToken", name);
	log(`  tokenName: ${args.tokenName}`, "deployFiatToken", name);
	log(`  tokenSymbol: ${args.tokenSymbol}`, "deployFiatToken", name);
	log(`  tokenCurrency: ${args.tokenCurrency}`, "deployFiatToken", name);
	log(`  tokenDecimals: ${args.tokenDecimals}`, "deployFiatToken", name);

	const signatureCheckerArtifactPath = path.resolve(
		__dirname,
		"../usdc-artifacts/SignatureChecker.sol/SignatureChecker.json",
	);
	const signatureCheckerArtifact = JSON.parse(
		fs.readFileSync(signatureCheckerArtifactPath, "utf8"),
	);

	const signatureCheckerDeployment = await deploy("SignatureChecker", {
		from: deployer,
		contract: {
			abi: signatureCheckerArtifact.abi,
			bytecode: signatureCheckerArtifact.bytecode,
		},
		args: [],
		log: true,
		autoMine: true,
	});

	const artifactPath = path.resolve(
		__dirname,
		"../usdc-artifacts/FiatTokenV2_2.sol/FiatTokenV2_2.json",
	);
	const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

	const deployment = await deploy("FiatTokenV2_2", {
		from: deployer,
		contract: {
			abi: artifact.abi,
			bytecode: artifact.bytecode,
		},
		libraries: {
			"contracts/util/SignatureChecker.sol:SignatureChecker":
				signatureCheckerDeployment.address,
		},
		args: [],
		log: true,
		autoMine: true,
	});

	log(`Deployed at: ${deployment.address}`, "deployFiatToken", name);

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
