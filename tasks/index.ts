import { configureMinterTask } from "./configureMinter.task";

import { addDstBridgeTask } from "./addDstBridge.task";
import { addDstPoolTask } from "./addDstPool.task";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner.task";
import { deployBridgeTask } from "./deployBridge/deployBridge.task";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatToken.task";
import deployConceroPauseToAllChains from "./deployPause/deployConceroPauseToAllChains.task";
import deployPauseTask from "./deployPause/deployPause.task";
import { deployPoolTask } from "./deployPool/deployPool.task";
import fiatTokenChangeAdmin from "./fiatTokenChangeAdmin.task";
import fiatTokenTransferOwnership from "./fiatTokenTransferOwnership.task";
import { getRateInfoTask } from "./getRateInfo.task";
import { removeDstBridgeTask } from "./removeDstBridge.task";
import { removeDstPoolTask } from "./removeDstPool.task";
import { sendTokenTask } from "./sendToken.task";
import { setRateLimitsTask } from "./setRateLimits.task";
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
