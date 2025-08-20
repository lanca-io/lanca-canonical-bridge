import { configureMinterTask } from "./deployFiatToken/configureMinterTask";

import { addDstBridgeTask } from "./addDstBridge/addDstBridgeTask";
import { addDstPoolTask } from "./addDstPool/addDstPoolTask";
import { removeDstBridgeTask } from "./removeDstBridge/removeDstBridgeTask";
import { removeDstPoolTask } from "./removeDstPool/removeDstPoolTask";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwnerTask";
import { deployBridgeTask } from "./deployBridge/deployBridge.task";
import { setRateLimitsTask } from "./setRateLimits/setRateLimits.task";
import fiatTokenChangeAdmin from "./deployFiatToken/changeAdmin.task";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import fiatTokenTransferOwnership from "./deployFiatToken/transferOwnership.task";
import { deployPoolTask } from "./deployPool/deployPoolTask";
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
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	sendTokenTask,
	setRateLimitsTask,
	deployPauseTask,
	deployConceroPauseToAllChains,
	updateAllPools,
	updateAllBridges,
	fiatTokenTransferOwnership,
	fiatTokenChangeAdmin,
};
