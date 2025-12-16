import { task } from "hardhat/config";

import { type HardhatRuntimeEnvironment } from "hardhat/types";
import { encodeFunctionData } from "viem";

import { ProxyEnum, proxyAbi } from "../../constants";
import { deployLancaCanonicalBridge } from "../../deploy/LancaCanonicalBridge";
import { deployTransparentProxy } from "../../deploy/TransparentProxy";
import { compileContracts } from "../../utils";
import { configureMinter, setLibs, setRateLimits, upgradeLancaProxyImplementation } from "../utils";

async function deployBridgeTask(taskArgs: any, hre: HardhatRuntimeEnvironment) {
	compileContracts({ quiet: true });

	const isL1Deployment =
		hre.network.name === "ethereum" || hre.network.name === "ethereumSepolia";

	if (taskArgs.implementation) {
		await deployLancaCanonicalBridge(hre);
	}

	if (taskArgs.proxy) {
		const [deployer] = await hre.ethers.getSigners();
		const callData = encodeFunctionData({
			abi: proxyAbi,
			functionName: "initialize",
			args: [deployer.address],
		});
		await deployTransparentProxy(hre, ProxyEnum.lcBridgeProxy, callData);
	}

	if (taskArgs.implementation) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, false);
	}

	if (taskArgs.proxy && !isL1Deployment && !taskArgs.pause) {
		await setRateLimits(hre.network.name);
		await setLibs(hre.network.name);
		await configureMinter(hre.network.name);
	}

	if (taskArgs.pause) {
		await upgradeLancaProxyImplementation(hre, ProxyEnum.lcBridgeProxy, true);
	}
}

// yarn hardhat deploy-bridge [--implementation] [--proxy] [--pause] --network <network_name>
task("deploy-bridge", "Deploy LancaCanonicalBridge")
	.addFlag("implementation", "Deploy implementation")
	.addFlag("proxy", "Deploy proxy and proxy admin")
	.addOptionalParam("owner", "Override proxy admin owner address")
	.addFlag("pause", "Pause bridge")
	.setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
		await deployBridgeTask(taskArgs, hre);
	});

export { deployBridgeTask };
