import { addDstBridgeTask } from "./addDstBridge/addDstBridgeTask";
import { changeProxyAdminOwnerTask } from "./changeProxyAdminOwner/changeProxyAdminOwnerTask";
import { deployBridgeL1Task } from "./deployBridge/deployBridgeL1Task";
import { deployBridgeTask } from "./deployBridge/deployBridgeTask";
import { setRateLimitsTask } from "./deployBridge/setRateLimitsTask";
import fiatTokenChangeAdmin from "./deployFiatToken/changeAdmin.task";
import { configureMinterTask } from "./deployFiatToken/configureMinterTask";
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
