import { configureMinterTask } from "./deployFiatToken/configureMinterTask";

import { addDstBridgeTask } from "./addDstBridge/addDstBridgeTask";
import { addDstPoolTask } from "./addDstPool/addDstPoolTask";
import { removeDstBridgeTask } from "./removeDstBridge/removeDstBridgeTask";
import { removeDstPoolTask } from "./removeDstPool/removeDstPoolTask";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwnerTask";
import { deployBridgeL1Task } from "./deployBridge/deployBridgeL1Task";
import { deployBridgeTask } from "./deployBridge/deployBridgeTask";
import { setRateLimitsTask } from "./deployBridge/setRateLimitsTask";
import fiatTokenChangeAdmin from "./deployFiatToken/changeAdmin.task";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import fiatTokenTransferOwnership from "./deployFiatToken/transferOwnership.task";
import { deployPoolTask } from "./deployPool/deployPoolTask";
import { mintTestUsdcTask } from "./mintTestUsdc/mintTestUsdcTask";
import deployConceroPauseToAllChains from "./pause/deployConceroPauseToAllChains";
import deployPauseTask from "./pause/deployPause.task";
import { sendTokenTask } from "./sendToken/sendTokenTask";
import updateAllBridges from "./updateAllBridges.task";
import updateAllPools from "./updateAllPools.task";

export default {
	addDstBridgeTask,
	addDstPoolTask,
	removeDstBridgeTask,
	removeDstPoolTask,
	changeProxyAdminOwnerTask,
	deployBridgeTask,
	deployBridgeL1Task,
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	mintTestUsdcTask,
	sendTokenTask,
	setRateLimitsTask,
	deployPauseTask,
	deployConceroPauseToAllChains,
	updateAllPools,
	updateAllBridges,
	fiatTokenTransferOwnership,
	fiatTokenChangeAdmin,
};
