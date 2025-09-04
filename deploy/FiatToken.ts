import { getNetworkEnvKey } from "@concero/contract-utils";
import { hardhatDeployWrapper } from "@concero/contract-utils";
import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { conceroNetworks } from "../constants";
import { DEPLOY_CONFIG_TESTNET } from "../constants/deployConfigTestnet";
import { copyMetadataForVerification, saveVerificationData } from "../tasks/utils";
import { getFallbackClients, getViemAccount, log, updateEnvVariable } from "../utils";

const deployFiatToken = async function (hre: HardhatRuntimeEnvironment): Promise<Deployment> {
	const { name } = hre.network;

	const chain = conceroNetworks[name as keyof typeof conceroNetworks];
	const { type: networkType } = chain;

	log(`Deploying FiatToken implementation:`, "deployFiatToken", name);

	const viemAccount = getViemAccount(networkType, "proxyDeployer");
	const { publicClient } = getFallbackClients(chain, viemAccount);

	let gasLimit = 0;
	const config = DEPLOY_CONFIG_TESTNET[name];
	if (config) {
		gasLimit = config.usdc?.gasLimit || 0;
	}

	const signatureCheckerDeployment = await hardhatDeployWrapper("SignatureChecker", {
		hre,
		args: [],
		publicClient,
		gasLimit,
	});

	const deployment = await hardhatDeployWrapper("FiatTokenV2_2", {
		hre,
		args: [],
		publicClient,
		gasLimit,
		libraries: {
			SignatureChecker: signatureCheckerDeployment.address,
		},
	});

	log(`Deployed at: ${deployment.address} \n`, "deployFiatToken", name);

	updateEnvVariable(
		`USDC_${getNetworkEnvKey(name)}`,
		deployment.address,
		`deployments.${networkType}` as const,
	);

	await saveVerificationData(
		name,
		"SignatureChecker",
		signatureCheckerDeployment.address,
		signatureCheckerDeployment.transactionHash || "",
	);
	await saveVerificationData(
		name,
		"FiatTokenV2_2",
		deployment.address,
		deployment.transactionHash || "",
	);

	await copyMetadataForVerification(name, "SignatureChecker");
	await copyMetadataForVerification(name, "FiatTokenV2_2");

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
