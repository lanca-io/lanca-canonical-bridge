import * as fs from "fs";
import * as path from "path";

import { conceroNetworks } from "../../constants";
import { log } from "../../utils";

interface VerificationContract {
	contractAddress: string;
	contractCreationTxHash: string;
	verificationType?: string;
	useTracesForCreationBytecode?: boolean;
	artifactType?: string;
	optimizerRuns?: number;
}

interface VerificationData {
	SignatureChecker: VerificationContract;
	FiatTokenV2_2: VerificationContract;
	FiatTokenProxy: VerificationContract;
	rpcUrl: string;
}

export async function saveVerificationData(
	chainName: string,
	contractName: "SignatureChecker" | "FiatTokenV2_2" | "FiatTokenProxy",
	contractAddress: string,
	contractCreationTxHash: string,
	rpcUrl?: string,
): Promise<void> {
	const network = conceroNetworks[chainName as keyof typeof conceroNetworks];

	const chainDir = path.join(process.cwd(), "all_verification_artifacts", chainName);
	const chainVerificationDir = path.join(chainDir, "verification_artifacts");
	const inputFilePath = path.join(chainVerificationDir, "input.json");

	if (!fs.existsSync(chainVerificationDir)) {
		fs.mkdirSync(chainVerificationDir, { recursive: true });
	}

	let verificationData: VerificationData;

	if (fs.existsSync(inputFilePath)) {
		const existingData = fs.readFileSync(inputFilePath, "utf8");
		verificationData = JSON.parse(existingData);
	} else {
		const templatePath = path.join(
			process.cwd(),
			"verification_artifacts",
			"input.template.json",
		);
		if (fs.existsSync(templatePath)) {
			const templateData = fs.readFileSync(templatePath, "utf8");
			verificationData = JSON.parse(templateData);
		} else {
			verificationData = {
				SignatureChecker: {
					contractAddress: "",
					contractCreationTxHash: "",
				},
				FiatTokenV2_2: {
					contractAddress: "",
					contractCreationTxHash: "",
				},
				FiatTokenProxy: {
					contractAddress: "",
					contractCreationTxHash: "",
				},
				rpcUrl: "",
			};
		}
	}

	verificationData[contractName] = {
		contractAddress,
		contractCreationTxHash,
		verificationType: "partial",
	};

	if (network.url) {
		verificationData.rpcUrl = network.url;
	} else {
		log(`Warning: RPC URL not found for ${chainName}`, "saveVerificationData", chainName);
	}

	fs.writeFileSync(inputFilePath, JSON.stringify(verificationData, null, 2));

	log(
		`Verification data saved for ${contractName}: ${contractAddress}`,
		"saveVerificationData",
		chainName,
	);
}

export async function copyMetadataForVerification(
	chainName: string,
	contractName: "SignatureChecker" | "FiatTokenV2_2" | "FiatTokenProxy",
): Promise<void> {
	const chainDir = path.join(process.cwd(), "all_verification_artifacts", chainName);
	const chainVerificationDir = path.join(chainDir, "verification_artifacts");

	if (!fs.existsSync(chainVerificationDir)) {
		fs.mkdirSync(chainVerificationDir, { recursive: true });
	}

	let dbgJsonPath: string;
	let contractPath: string;

	switch (contractName) {
		case "SignatureChecker":
			dbgJsonPath = path.join(
				process.cwd(),
				"artifacts",
				"contracts",
				"usdc",
				"util",
				"SignatureChecker.sol",
				"SignatureChecker.dbg.json",
			);
			contractPath = "contracts/usdc/util/SignatureChecker.sol";
			break;
		case "FiatTokenV2_2":
			dbgJsonPath = path.join(
				process.cwd(),
				"artifacts",
				"contracts",
				"usdc",
				"v2",
				"FiatTokenV2_2.sol",
				"FiatTokenV2_2.dbg.json",
			);
			contractPath = "contracts/usdc/v2/FiatTokenV2_2.sol";
			break;
		case "FiatTokenProxy":
			dbgJsonPath = path.join(
				process.cwd(),
				"artifacts",
				"contracts",
				"usdc",
				"v1",
				"FiatTokenProxy.sol",
				"FiatTokenProxy.dbg.json",
			);
			contractPath = "contracts/usdc/v1/FiatTokenProxy.sol";
			break;
		default:
			throw new Error(`Unknown contract name: ${contractName}`);
	}

	try {
		if (!fs.existsSync(dbgJsonPath)) {
			log(
				`Warning: Debug file not found at ${dbgJsonPath}`,
				"copyMetadataForVerification",
				chainName,
			);
			return;
		}

		const dbgContent = JSON.parse(fs.readFileSync(dbgJsonPath, "utf8"));
		const buildInfoPath = dbgContent.buildInfo;

		if (!buildInfoPath) {
			log(
				`Warning: buildInfo not found in ${dbgJsonPath}`,
				"copyMetadataForVerification",
				chainName,
			);
			return;
		}

		const absoluteBuildInfoPath = path.resolve(path.dirname(dbgJsonPath), buildInfoPath);

		if (!fs.existsSync(absoluteBuildInfoPath)) {
			log(
				`Warning: Build info file not found at ${absoluteBuildInfoPath}`,
				"copyMetadataForVerification",
				chainName,
			);
			return;
		}

		const buildInfo = JSON.parse(fs.readFileSync(absoluteBuildInfoPath, "utf8"));

		const contractOutput = buildInfo.output?.contracts?.[contractPath]?.[contractName];

		if (!contractOutput?.metadata) {
			log(
				`Warning: Metadata not found for ${contractName} in build info`,
				"copyMetadataForVerification",
				chainName,
			);
			return;
		}

		const metadata = JSON.parse(contractOutput.metadata);

		const destinationPath = path.join(chainVerificationDir, `${contractName}.json`);
		fs.writeFileSync(destinationPath, JSON.stringify(metadata, null, 2));

		log(
			`Metadata extracted and saved for ${contractName}`,
			"copyMetadataForVerification",
			chainName,
		);
	} catch (error) {
		log(
			`Error extracting metadata for ${contractName}: ${error}`,
			"copyMetadataForVerification",
			chainName,
		);
	}
}
