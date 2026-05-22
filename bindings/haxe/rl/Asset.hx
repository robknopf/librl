/** Public façade: Asset subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Asset {

	public static inline var ADD_TASK_OK:Int = rl.impl.RLImpl.ASSET_ADD_TASK_OK;
	public static inline var ADD_TASK_ERR_INVALID:Int = rl.impl.RLImpl.ASSET_ADD_TASK_ERR_INVALID;
	public static inline var ADD_TASK_ERR_QUEUE_FULL:Int = rl.impl.RLImpl.ASSET_ADD_TASK_ERR_QUEUE_FULL;


	public static function setHost(assetHost:String):Int {
		return rl.impl.RLImpl.assetSetHost(assetHost);
	}

	public static function getHost():String {
		return rl.impl.RLImpl.assetGetHost();
	}

	public static function pingHost(?assetHost:String):Float {
		return rl.impl.RLImpl.assetPingHost(assetHost);
	}

	public static function ensureAsync(localPath:String, ?src:String):RLHandle {
		return rl.impl.RLImpl.assetEnsureAsync(localPath, src);
	}

	@async
	public static function ensure(localPath:String, ?src:String):Int {
		return cast rl.impl.RLImpl.assetEnsure(localPath, src);
	}

	public static function ensureGroupAsync(filenames:Array<String>):RLHandle {
		return rl.impl.RLImpl.assetEnsureGroupAsync(filenames);
	}

	public static function pollTask(task:RLHandle):Bool {
		return rl.impl.RLImpl.assetPollTask(task);
	}

	public static function finishTask(task:RLHandle):Int {
		return rl.impl.RLImpl.assetFinishTask(task);
	}

	public static function getTaskPath(task:RLHandle):String {
		return rl.impl.RLImpl.assetGetTaskPath(task);
	}

	public static function freeTask(task:RLHandle):Void {
		rl.impl.RLImpl.assetFreeTask(task);
	}

	public static function addTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int {
		return rl.impl.RLImpl.assetAddTask(task, onSuccess, onFailure, ctx);
	}

	public static function tick():Void {
		rl.impl.RLImpl.assetTick();
	}

	public static function taskInvalid():RLHandle {
		return rl.impl.RLImpl.assetTaskInvalid();
	}

	public static function taskIsValid(task:RLHandle):Bool {
		return rl.impl.RLImpl.assetTaskIsValid(task);
	}
}
