package rl;

import haxe.io.Bytes;

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
@:headerInclude("string.h")
class RLLoader {
  @:functionCode('
    return ::rl_loader_init(mountPoint.length == 0 ? (const char *)0 : mountPoint.utf8_str());
  ')
  static function initNative(mountPoint: String): Int {
    return 0;
  }

  @:functionCode('
    ::rl_loader_deinit();
  ')
  static function deinitNative(): Void {}

  @:functionCode('
    ::rl_loader_task_t *task = ::rl_loader_restore_fs_async();
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function restoreFsAsyncNative(): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  @:functionCode('
    ::rl_loader_task_t *task = ::rl_loader_create_import_task(filename.utf8_str());
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
    ::rl_loader_task_t *task = ::rl_loader_import_assets_async((const char *const *)ptrs, (size_t)n);
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function importAssetsAsyncNative(filenames: Array<String>): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  @:functionCode('
    return ::rl_loader_poll_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function pollTaskNative(task: RLLoaderTaskPtr): Bool {
    return false;
  }

  @:functionCode('
    return ::rl_loader_finish_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function finishTaskNative(task: RLLoaderTaskPtr): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_loader_get_task_path((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function getTaskPathNative(task: RLLoaderTaskPtr): String {
    return null;
  }

  @:functionCode('
    ::rl_loader_read_result_t result = ::rl_loader_read_local(filename.utf8_str());
    if (result.error != 0 || result.data == nullptr) {
      ::rl_loader_read_result_free(&result);
      return null();
    }

    Array<unsigned char> data = Array_obj<unsigned char>::__new((int)result.size, (int)result.size);
    if (result.size > 0) {
      ::memcpy(data->GetBase(), result.data, result.size);
    }
    ::rl_loader_read_result_free(&result);
    return ::haxe::io::Bytes_obj::__alloc(HX_CTX_GET, (int)data->length, data);
  ')
  static function readLocalNative(filename: String): Bytes {
    return null;
  }

  @:functionCode('
    ::rl_loader_free_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function freeTaskNative(task: RLLoaderTaskPtr): Void {}

  @:functionCode('
    return ::rl_loader_add_task((::rl_loader_task_t *)(uintptr_t)task, onSuccess, onFailure, userData);
  ')
  static function addTaskNative(task: RLLoaderTaskPtr,
    onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_loader_ping_asset_host(assetHost.utf8_str());
  ')
  static function pingAssetHostNative(assetHost: String): Float {
    return -1.0;
  }

  @:functionCode('
    return ::rl_loader_get_cache_dir();
  ')
  static function getCacheDirNative(): String {
    return null;
  }

  public static inline function loaderRestoreFsAsync(): RLLoaderTaskPtr {
    return restoreFsAsyncNative();
  }

  public static inline function loaderInit(?mountPoint: String): Int {
    return initNative(mountPoint == null ? "" : mountPoint);
  }

  public static inline function loaderDeinit(): Void {
    deinitNative();
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

  public static inline function loaderReadLocal(filename: String): Bytes {
    return readLocalNative(filename);
  }

  public static inline function loaderFreeTask(task: RLLoaderTaskPtr): Void {
    freeTaskNative(task);
  }

  public static inline function loaderIsAssetCached(filename: String): Bool {
    return isAssetCachedNative(filename);
  }

  public static inline function loaderAddTask(task: RLLoaderTaskPtr,
    onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return addTaskNative(task, onSuccess, onFailure, userData);
  }

  public static inline function loaderPingAssetHost(?assetHost: String): Float {
    return pingAssetHostNative(assetHost == null ? "" : assetHost);
  }

  public static inline function loaderGetCacheDir(): String {
    return getCacheDirNative();
  }

  public static inline function loaderTick(): Void {
    tickNative();
  }

  public static inline function loaderClearCache(): Int {
    return clearCacheNative();
  }

  public static inline function loaderUncacheAsset(filename: String): Int {
    return uncacheAssetNative(filename);
  }

  @:functionCode('
    return ::rl_loader_is_asset_cached(filename.utf8_str());
  ')
  static function isAssetCachedNative(filename: String): Bool {
    return false;
  }

  @:functionCode('
    ::rl_loader_tick();
  ')
  static function tickNative(): Void {}

  @:functionCode('
    return ::rl_loader_clear_cache();
  ')
  static function clearCacheNative(): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_loader_uncache_asset(filename.utf8_str());
  ')
  static function uncacheAssetNative(filename: String): Int {
    return 0;
  }
}
#else
typedef RLLoaderTaskPtr = Dynamic;
#end
