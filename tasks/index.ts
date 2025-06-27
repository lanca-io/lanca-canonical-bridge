import { addLaneTask } from "./addLane/addLaneTask";
import { configureMinterTask } from "./configureMinter/configureMinterTask";
import { deployBridgeL1Task } from "./deployBridge/deployBridgeL1Task";
import { deployBridgeTask } from "./deployBridge/deployBridgeTask";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import deployPauseTask from "./deployPause.task";
import { deployPoolTask } from "./deployPool/deployPoolTask";
import { mintTestUsdcTask } from "./mintTestUsdc/mintTestUsdcTask";
import deployConceroPauseToAllChains from "./pause/deployConceroPauseToAllChains";
import { sendTokenTask } from "./sendToken/sendTokenTask";
import updateAllPools from "./updateAllPools.task";
import updateAllBridges from "./updateAllBridges.task";

export default {
	addLaneTask,
	deployBridgeTask,
	deployBridgeL1Task,
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	mintTestUsdcTask,
	sendTokenTask,
	deployPauseTask,
	deployConceroPauseToAllChains,
	updateAllPools,
	updateAllBridges,
};
