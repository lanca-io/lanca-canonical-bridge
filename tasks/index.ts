import { configureMinterTask } from "./deployFiatToken/configureMinterTask";

import { addDstBridgeTask } from "./addDstBridge/addDstBridge.task";
import { addDstPoolTask } from "./addDstPool/addDstPool.task";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwner.task";
import { deployBridgeTask } from "./deployBridge/deployBridge.task";
import fiatTokenChangeAdmin from "./deployFiatToken/changeAdmin.task";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import fiatTokenTransferOwnership from "./deployFiatToken/transferOwnership.task";
import { deployPoolTask } from "./deployPool/deployPool.task";
import { getRateInfoTask } from "./getRateInfo/getRateInfo.task";
import deployConceroPauseToAllChains from "./pause/deployConceroPauseToAllChains";
import deployPauseTask from "./pause/deployPause.task";
import { removeDstBridgeTask } from "./removeDstBridge/removeDstBridgeTask";
import { removeDstPoolTask } from "./removeDstPool/removeDstPoolTask";
import { sendTokenTask } from "./sendToken/sendTokenTask";
import { setRateLimitsTask } from "./setRateLimits/setRateLimits.task";
import updateAllBridges from "./updateAllBridges.task";
import updateAllPools from "./updateAllPools.task";

export default {
	addDstBridgeTask,
	addDstPoolTask,
	removeDstBridgeTask,
	removeDstPoolTask,
	changeProxyAdminOwnerTask,
	deployBridgeTask,
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	sendTokenTask,
	setRateLimitsTask,
	getRateInfoTask,
	deployPauseTask,
	deployConceroPauseToAllChains,
	updateAllPools,
	updateAllBridges,
	fiatTokenTransferOwnership,
	fiatTokenChangeAdmin,
};
