/**
 * Async/poll helpers for asset and fs tasks (not part of the C API).
 *
 * JS equivalent: `RL.helpers.waitForTask()`, `RL.helpers.waitForFsReady()`, …
 */

package rl.helpers;

import rl.Asset;
import rl.Fs;
import rl.Types.RLHandle;

@:keep
class Wait {
	#if js
	@async
	#end
	public static function waitForTask(task:RLHandle, ?pollMs:Int):Int {
		#if js
		return cast rl.impl.RLImpl.helpersWaitForTask(task, pollMs);
		#else
		var delay = pollMs == null ? 16 : pollMs;
		if (!Asset.taskIsValid(task))
			return -1;
		while (!Asset.pollTask(task))
			Sys.sleep(delay / 1000.0);
		var rc = Asset.finishTask(task);
		Asset.freeTask(task);
		return rc;
		#end
	}

	#if js
	@async
	#end
	public static function waitForFsReady(?timeoutMs:Int):Bool {
		#if js
		return cast rl.impl.RLImpl.helpersWaitForFsReady(timeoutMs);
		#else
		var timeout = timeoutMs == null ? 2000 : timeoutMs;
		var start = haxe.Timer.stamp();
		while (haxe.Timer.stamp() - start < timeout / 1000.0) {
			if (Fs.isReady())
				return true;
			Sys.sleep(0.016);
		}
		return Fs.isReady();
		#end
	}

	#if js
	@async
	#end
	public static function waitForFsRestoreAsync():Int {
		return waitForTask(Fs.restoreAsync());
	}

	#if js
	@async
	#end
	public static function waitForAssetEnsureAsync(localPath:String, ?src:String):Int {
		return waitForTask(Asset.ensureAsync(localPath, src));
	}

	#if js
	@async
	#end
	public static function waitForAssetEnsureGroupAsync(filenames:Array<String>):Int {
		return waitForTask(Asset.ensureGroupAsync(filenames));
	}
}
