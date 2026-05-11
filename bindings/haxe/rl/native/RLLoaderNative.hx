/**
 * hxcpp-only loader implementation.
 * Contains RLLoaderTaskPtrImpl and the internal RLLoader class used by RLNative.hx.
 * Never imported directly by scripts.
 */
package rl.native;

#if cpp
abstract RLLoaderTaskPtrImpl(cpp.UInt64) from cpp.UInt64 to cpp.UInt64 {
  public static inline function invalid(): RLLoaderTaskPtrImpl {
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
    return ::rl_loader_init_async(mountPoint.length == 0 ? (const char *)0 : mountPoint.utf8_str());
  ')
  static function initAsyncNative(mountPoint: String): Int {
    return 0;
  }

  @:functionCode('
    ::rl_loader_deinit();
  ')
  static function deinitNative(): Void {}

  @:functionCode('
    return ::rl_loader_is_initialized();
  ')
  static function isInitializedNative(): Bool { return false; }

  @:functionCode('
    ::rl_loader_task_t *task = ::rl_loader_restore_fs_async();
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function restoreFsAsyncNative(): RLLoaderTaskPtrImpl {
    return RLLoaderTaskPtrImpl.invalid();
  }

  @:functionCode('
    ::rl_loader_task_t *task = ::rl_loader_create_import_task(filename.utf8_str());
    return (cpp::UInt64)(uintptr_t)task;
  ')
  static function importAssetAsyncNative(filename: String): RLLoaderTaskPtrImpl {
    return RLLoaderTaskPtrImpl.invalid();
  }

  @:functionCode('
    return ::rl_loader_import_asset_sync(filename.utf8_str());
  ')
  static function importAssetSyncNative(filename: String): Int {
    return -1;
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
  static function importAssetsAsyncNative(filenames: Array<String>): RLLoaderTaskPtrImpl {
    return RLLoaderTaskPtrImpl.invalid();
  }

  @:functionCode('
    return ::rl_loader_poll_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function pollTaskNative(task: RLLoaderTaskPtrImpl): Bool {
    return false;
  }

  @:functionCode('
    return ::rl_loader_finish_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function finishTaskNative(task: RLLoaderTaskPtrImpl): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_loader_get_task_path((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function getTaskPathNative(task: RLLoaderTaskPtrImpl): String {
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
  static function readLocalNative(filename: String): haxe.io.Bytes {
    return null;
  }

  @:functionCode('
    ::rl_loader_free_task((::rl_loader_task_t *)(uintptr_t)task);
  ')
  static function freeTaskNative(task: RLLoaderTaskPtrImpl): Void {}

  @:functionCode('
    return ::rl_loader_add_task((::rl_loader_task_t *)(uintptr_t)task, onSuccess, onFailure, userData);
  ')
  static function addTaskNative(task: RLLoaderTaskPtrImpl,
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

  public static function loaderRestoreFsAsync(): RLLoaderTaskPtrImpl {
    return restoreFsAsyncNative();
  }

  public static function loaderInit(?mountPoint: String): Int {
    return initNative(mountPoint == null ? "" : mountPoint);
  }

  public static function loaderInitAsync(?mountPoint: String): Int {
    return initAsyncNative(mountPoint == null ? "" : mountPoint);
  }

  public static function loaderDeinit(): Void {
    deinitNative();
  }

  public static function loaderIsInitialized(): Bool {
    return isInitializedNative();
  }

  public static function loaderImportAssetAsync(filename: String): RLLoaderTaskPtrImpl {
    return importAssetAsyncNative(filename);
  }

  public static function loaderImportAssetSync(filename: String): Int {
    return importAssetSyncNative(filename);
  }

  public static function loaderImportAssetsAsync(filenames: Array<String>): RLLoaderTaskPtrImpl {
    return cast importAssetsAsyncNative(filenames);
  }

  public static function loaderPollTask(task: RLLoaderTaskPtrImpl): Bool {
    return pollTaskNative(task);
  }

  public static function loaderFinishTask(task: RLLoaderTaskPtrImpl): Int {
    return finishTaskNative(task);
  }

  public static function loaderGetTaskPath(task: RLLoaderTaskPtrImpl): String {
    return getTaskPathNative(task);
  }

  public static function loaderReadLocal(filename: String): haxe.io.Bytes {
    return readLocalNative(filename);
  }

  public static function loaderFreeTask(task: RLLoaderTaskPtrImpl): Void {
    freeTaskNative(task);
  }

  public static function loaderIsAssetCached(filename: String): Bool {
    return isAssetCachedNative(filename);
  }

  public static function loaderAddTask(task: RLLoaderTaskPtrImpl,
    onSuccess: RLLoaderCallbackFn, onFailure: RLLoaderCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return addTaskNative(task, onSuccess, onFailure, userData);
  }

  public static function loaderPingAssetHost(?assetHost: String): Float {
    return pingAssetHostNative(assetHost == null ? "" : assetHost);
  }

  public static function loaderGetCacheDir(): String {
    return getCacheDirNative();
  }

  public static function loaderTick(): Void {
    tickNative();
  }

  public static function loaderClearCache(): Int {
    return clearCacheNative();
  }

  public static function loaderUncacheAsset(filename: String): Int {
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
#end
