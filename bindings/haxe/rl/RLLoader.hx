package rl;

#if cpp
abstract RLLoaderTaskPtr(cpp.UInt64) from cpp.UInt64 to cpp.UInt64 {
  public static inline function invalid(): RLLoaderTaskPtr {
    return cast (0 : cpp.UInt64);
  }

  public inline function isValid(): Bool {
    return this != (0 : cpp.UInt64);
  }
}
typedef RLLoaderCallbackFn = cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>;

@:headerInclude("rl_loader.h")
@:headerInclude("alloca.h")
@:headerInclude("stdint.h")
class RLLoader {
  @:functionCode('
    rl_loader_task_t *task = rl_loader_restore_fs_async();
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function restoreFsAsyncNative(): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  @:functionCode('
    rl_loader_task_t *task = rl_loader_import_asset_async(filename.utf8_str());
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function importAssetAsyncNative(filename: String): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  @:functionCode('
    int n = filenames->length;
    if (n <= 0) {
      return (cpp::UInt64)0;
    }
    const char **ptrs = (const char **)alloca(n * sizeof(const char *));
    for (int i = 0; i < n; i++) ptrs[i] = filenames->__get(i).utf8_str();
    rl_loader_task_t *task = rl_loader_import_assets_async((const char *const *)ptrs, (size_t)n);
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function importAssetsAsyncNative(filenames: Array<String>): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  @:functionCode('
    return rl_loader_poll_task((rl_loader_task_t *)(uintptr_t)task);
  ')
  static function pollTaskNative(task: RLLoaderTaskPtr): Bool {
    return false;
  }

  @:functionCode('
    return rl_loader_finish_task((rl_loader_task_t *)(uintptr_t)task);
  ')
  static function finishTaskNative(task: RLLoaderTaskPtr): Int {
    return 0;
  }

  @:functionCode('
    return rl_loader_get_task_path((rl_loader_task_t *)(uintptr_t)task);
  ')
  static function getTaskPathNative(task: RLLoaderTaskPtr): String {
    return null;
  }

  @:functionCode('
    rl_loader_free_task((rl_loader_task_t *)(uintptr_t)task);
  ')
  static function freeTaskNative(task: RLLoaderTaskPtr): Void {}

  @:functionCode('
    return rl_loader_queue_task((rl_loader_task_t *)(uintptr_t)task, path.utf8_str(), onSuccess, onFailure, userData);
  ')
  static function queueTaskNative(task: RLLoaderTaskPtr, path: String,
    onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return 0;
  }

  public static inline function loaderRestoreFsAsync(): RLLoaderTaskPtr {
    return restoreFsAsyncNative();
  }

  public static inline function loaderImportAssetAsync(filename: String): RLLoaderTaskPtr {
    return importAssetAsyncNative(filename);
  }

  public static inline function loaderImportAssetsAsync(filenames: Array<String>): RLLoaderTaskPtr {
    return cast importAssetsAsyncNative(filenames);
  }

  public static inline function loaderPollTask(task: RLLoaderTaskPtr): Bool {
    return pollTaskNative(task);
  }

  public static inline function loaderFinishTask(task: RLLoaderTaskPtr): Int {
    return finishTaskNative(task);
  }

  public static inline function loaderGetTaskPath(task: RLLoaderTaskPtr): String {
    return getTaskPathNative(task);
  }

  public static inline function loaderFreeTask(task: RLLoaderTaskPtr): Void {
    freeTaskNative(task);
  }

  public static inline function loaderIsLocal(filename: String): Bool {
    return isLocalNative(filename);
  }

  public static inline function loaderQueueTask(task: RLLoaderTaskPtr, path: String,
    onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return queueTaskNative(task, path, onSuccess, onFailure, userData);
  }

  public static inline function loaderTick(): Void {
    tickNative();
  }

  public static inline function loaderClearCache(): Int {
    return clearCacheNative();
  }

  public static inline function loaderUncacheFile(filename: String): Int {
    return uncacheFileNative(filename);
  }

  @:native("rl_loader_is_local")
  static function isLocalNative(filename: String): Bool {
    return false;
  }

  @:native("rl_loader_tick")
  static function tickNative(): Void {}

  @:native("rl_loader_clear_cache")
  static function clearCacheNative(): Int {
    return 0;
  }

  @:native("rl_loader_uncache_file")
  static function uncacheFileNative(filename: String): Int {
    return 0;
  }
}
#else
typedef RLLoaderTaskPtr = Dynamic;
#end
