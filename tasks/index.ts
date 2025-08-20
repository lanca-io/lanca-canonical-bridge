import { configureMinterTask } from "./deployFiatToken/configureMinter.task";

import { addDstBridgeTask } from "./addDstBridge/addDstBridge.task";
import { addDstPoolTask } from "./addDstPool/addDstPool.task";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwner.task";
import { deployBridgeTask } from "./deployBridge/deployBridge.task";
import fiatTokenChangeAdmin from "./deployFiatToken/changeAdmin.task";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatToken.task";
import fiatTokenTransferOwnership from "./deployFiatToken/transferOwnership.task";
import { deployPoolTask } from "./deployPool/deployPool.task";
import { getRateInfoTask } from "./getRateInfo/getRateInfo.task";
import deployConceroPauseToAllChains from "./pause/deployConceroPauseToAllChains.task";
import deployPauseTask from "./pause/deployPause.task";
import { removeDstBridgeTask } from "./removeDstBridge/removeDstBridge.task";
import { removeDstPoolTask } from "./removeDstPool/removeDstPool.task";
import { sendTokenTask } from "./sendToken/sendToken.task";
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
