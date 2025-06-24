import { configureMinterTask } from "./configureMinter/configureMinterTask";
import { deployBridgeL1Task } from "./deployBridge/deployBridgeL1Task";
import { deployBridgeTask } from "./deployBridge/deployBridgeTask";
import { deployFiatTokenTask } from "./deployFiatToken/deployFiatTokenTask";
import { deployPoolTask } from "./deployPool/deployPoolTask";
import { mintTestUsdcTask } from "./mintTestUsdc/mintTestUsdcTask";

export default {
	deployBridgeTask,
	deployBridgeL1Task,
	deployPoolTask,
	deployFiatTokenTask,
	configureMinterTask,
	mintTestUsdcTask,
};
