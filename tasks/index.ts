import { addLaneTask } from "./addLane/addLaneTask";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwnerTask";
import { configureMinterTask } from "./deployFiatToken/configureMinterTask";
import { deployBridgeL1Task } from "./deployBridge/deployBridgeL1Task";
import { deployBridgeTask } from "./deployBridge/deployBridgeTask";
import { setFlowLimitsTask } from "./deployBridge/setFlowLimitsTask";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import { deployPoolTask } from "./deployPool/deployPoolTask";
import { mintTestUsdcTask } from "./mintTestUsdc/mintTestUsdcTask";
import deployConceroPauseToAllChains from "./pause/deployConceroPauseToAllChains";
import deployPauseTask from "./pause/deployPause.task";
import { sendTokenTask } from "./sendToken/sendTokenTask";
import updateAllBridges from "./updateAllBridges.task";
import updateAllPools from "./updateAllPools.task";
import  fiatTokenTransferOwnership  from "./deployFiatToken/transferOwnership.task";
import  fiatTokenChangeAdmin  from "./deployFiatToken/changeAdmin.task";

export default {
	addLaneTask,
	changeProxyAdminOwnerTask,
	deployBridgeTask,
	deployBridgeL1Task,
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	mintTestUsdcTask,
	sendTokenTask,
	setFlowLimitsTask,
	deployPauseTask,
	deployConceroPauseToAllChains,
	updateAllPools,
	updateAllBridges,
	fiatTokenTransferOwnership,
	fiatTokenChangeAdmin,
};
