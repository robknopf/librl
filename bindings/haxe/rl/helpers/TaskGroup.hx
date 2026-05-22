/**
 * Binding helper: batch asset task polling (not part of the C API).
 *
 * Usage: `TaskGroup.create()` then `addImportTask` / `process()`.
 * JS equivalent: `RL.helpers.createTaskGroup()`.
 */

package rl.helpers;

import rl.Asset;
import rl.Types.RLHandle;

typedef TaskGroupTaskCallback<T> = String->T->Void;
typedef TaskGroupCallback<T> = TaskGroup->T->Void;

typedef TaskGroupEntry = {
	var task:RLHandle;
	var path:String;
	var done:Bool;
	var rc:Int;
	var onSuccess:Null<TaskGroupTaskCallback<Dynamic>>;
	var onError:Null<TaskGroupTaskCallback<Dynamic>>;
}

@:keep
class TaskGroup {
	var entries:Array<TaskGroupEntry>;
	var callbackContext:Dynamic;
	var onCompleteCallback:Null<TaskGroupCallback<Dynamic>>;
	var onErrorCallback:Null<TaskGroupCallback<Dynamic>>;
	var terminalCallbackInvoked:Bool;
	public var failedCount(default, null):Int;
	public var completedCount(default, null):Int;

	public static function create<T>(?onComplete:TaskGroupCallback<T>, ?onError:TaskGroupCallback<T>, ?ctx:T):TaskGroup {
		return new TaskGroup(cast onComplete, cast onError, ctx);
	}

	public function new(?onComplete:TaskGroupCallback<Dynamic>, ?onError:TaskGroupCallback<Dynamic>, ?ctx:Dynamic) {
		entries = [];
		failedCount = 0;
		completedCount = 0;
		callbackContext = ctx;
		onCompleteCallback = onComplete;
		onErrorCallback = onError;
		terminalCallbackInvoked = false;
	}

	public function addTask<T>(task:RLHandle, ?onSuccess:TaskGroupTaskCallback<T>, ?onError:TaskGroupTaskCallback<T>):Void {
		if (!task.isValid()) {
			return;
		}
		entries.push({
			task: task,
			path: Asset.getTaskPath(task),
			done: false,
			rc: 1,
			onSuccess: cast onSuccess,
			onError: cast onError
		});
	}

	public function addImportTask<T>(path:String, ?onSuccess:TaskGroupTaskCallback<T>, ?onError:TaskGroupTaskCallback<T>):Void {
		addTask(Asset.ensureAsync(path), onSuccess, onError);
	}

	public function addImportTasks(paths:Array<String>):Void {
		for (path in paths) {
			addImportTask(path);
		}
	}

	public function remainingTasks():Int {
		return entries.length - completedCount;
	}

	public function isDone():Bool {
		return remainingTasks() == 0;
	}

	public function hasFailures():Bool {
		return failedCount > 0;
	}

	public function tick():Bool {
		Asset.tick();
		for (entry in entries) {
			if (entry.done) {
				continue;
			}
			if (!Asset.pollTask(entry.task)) {
				continue;
			}
			entry.rc = Asset.finishTask(entry.task);
			Asset.freeTask(entry.task);
			entry.done = true;
			completedCount++;
			if (entry.rc != 0) {
				failedCount++;
				if (entry.onError != null) {
					entry.onError(entry.path, callbackContext);
				}
			} else if (entry.onSuccess != null) {
				entry.onSuccess(entry.path, callbackContext);
			}
		}
		return remainingTasks() > 0;
	}

	/** QoL helper: advance once and return remaining pending tasks. */
	public function process():Int {
		tick();
		if (!terminalCallbackInvoked && remainingTasks() == 0) {
			terminalCallbackInvoked = true;
			if (hasFailures()) {
				if (onErrorCallback != null) {
					onErrorCallback(this, callbackContext);
				}
			} else if (onCompleteCallback != null) {
				onCompleteCallback(this, callbackContext);
			}
		}
		return remainingTasks();
	}

	public function failedPaths():Array<String> {
		var out:Array<String> = [];
		for (entry in entries) {
			if (entry.done && entry.rc != 0) {
				out.push(entry.path);
			}
		}
		return out;
	}
}
