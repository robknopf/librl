package rl;
import rl.RLLoader;
import rl.RLLoader.RLLoaderTaskPtr;

typedef RLTaskGroupTaskCallback<T> = String->T->Void;
typedef RLTaskGroupCallback<T> = RLTaskGroup->T->Void;
typedef RLTaskGroupEntry = {
  var task:RLLoaderTaskPtr;
  var path:String;
  var done:Bool;
  var rc:Int;
  var onSuccess:Null<RLTaskGroupTaskCallback<Dynamic>>;
  var onError:Null<RLTaskGroupTaskCallback<Dynamic>>;
}

class RLTaskGroup {
  var entries:Array<RLTaskGroupEntry>;
  var callbackContext:Dynamic;
  var onCompleteCallback:Null<RLTaskGroupCallback<Dynamic>>;
  var onErrorCallback:Null<RLTaskGroupCallback<Dynamic>>;
  var terminalCallbackInvoked:Bool;
  public var failedCount(default, null):Int;
  public var completedCount(default, null):Int;

  public function new(?onComplete:RLTaskGroupCallback<Dynamic>, ?onError:RLTaskGroupCallback<Dynamic>, ?ctx:Dynamic) {
    entries = [];
    failedCount = 0;
    completedCount = 0;
    callbackContext = ctx;
    onCompleteCallback = onComplete;
    onErrorCallback = onError;
    terminalCallbackInvoked = false;
  }

  public inline function addTask<T>(task:RLLoaderTaskPtr, ?onSuccess:RLTaskGroupTaskCallback<T>, ?onError:RLTaskGroupTaskCallback<T>):Void {
    if (!task.isValid()) {
      return;
    }
    entries.push({
      task: task,
      path: RLLoader.loaderGetTaskPath(task),
      done: false,
      rc: 1,
      onSuccess: cast onSuccess,
      onError: cast onError
    });
  }

  public inline function addImportTask<T>(path:String, ?onSuccess:RLTaskGroupTaskCallback<T>, ?onError:RLTaskGroupTaskCallback<T>):Void {
    addTask(RLLoader.loaderImportAssetAsync(path), onSuccess, onError);
  }

  public inline function addImportTasks(paths:Array<String>):Void {
    for (path in paths) {
      addImportTask(path);
    }
  }

  public inline function remainingTasks():Int {
    return entries.length - completedCount;
  }

  public inline function isDone():Bool {
    return remainingTasks() == 0;
  }

  public inline function hasFailures():Bool {
    return failedCount > 0;
  }

  public function tick():Bool {
    RLLoader.loaderTick();
    for (entry in entries) {
      if (entry.done) {
        continue;
      }
      if (!RLLoader.loaderPollTask(entry.task)) {
        continue;
      }
      entry.rc = RLLoader.loaderFinishTask(entry.task);
      RLLoader.loaderFreeTask(entry.task);
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
  public inline function process():Int {
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
