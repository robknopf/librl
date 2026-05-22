/**
 * hxcpp-only fileio implementation.
 * Contains the internal RLFileio class used by RLImpl.cpp.hx.
 * Never imported directly by scripts.
 */
package rl.impl;

#if cpp
import rl.Types.RLHandle;

typedef RLFileioCallbackFn = cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>;

@:keep
@:headerInclude("rl_fs.h")
@:headerInclude("rl_asset.h")
@:headerInclude("alloca.h")
@:headerInclude("stdint.h")
@:headerInclude("string.h")
class RLFileio {
  @:functionCode('
    return ::rl_fs_init(baseDir.length == 0 ? (const char *)0 : baseDir.utf8_str());
  ')
  static function initNative(baseDir: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_init_async(baseDir.length == 0 ? (const char *)0 : baseDir.utf8_str());
  ')
  static function initAsyncNative(baseDir: String): Int {
    return 0;
  }

  @:functionCode('
    ::rl_fs_deinit();
  ')
  static function deinitNative(): Void {}

  @:functionCode('
    return (int)::rl_fs_deinit_async();
  ')
  static function deinitAsyncNative(): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_is_initialized();
  ')
  static function isInitializedNative(): Bool { return false; }

  @:functionCode('
    return ::rl_fs_is_ready();
  ')
  static function isReadyNative(): Bool { return false; }

  @:functionCode('
    return ::rl_fs_flush();
  ')
  static function flushNative(): Int { return 0; }

  @:functionCode('
    return (int)::rl_fs_restore_async();
  ')
  static function restoreAsyncNative(): RLHandle {
    return 0;
  }

  @:functionCode('
    return (int)::rl_asset_ensure_async(
      localPath.utf8_str(),
      src.length == 0 ? (const char *)0 : src.utf8_str()
    );
  ')
  static function ensureAsyncNative(localPath: String, src: String): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_asset_ensure(
      localPath.utf8_str(),
      src.length == 0 ? (const char *)0 : src.utf8_str()
    );
  ')
  static function ensureNative(localPath: String, src: String): Int {
    return -1;
  }

  @:functionCode('
    int n = filenames->length;
    if (n <= 0) {
      return 0;
    }
    const char **ptrs = (const char **)alloca(n * sizeof(const char *));
    for (int i = 0; i < n; i++) ptrs[i] = filenames->__get(i).utf8_str();
    return (int)::rl_asset_ensure_many_async((const char *const *)ptrs, (size_t)n);
  ')
  static function ensureGroupAsyncNative(filenames: Array<String>): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_asset_poll_task((::rl_handle_t)task);
  ')
  static function pollNative(task: RLHandle): Bool {
    return false;
  }

  @:functionCode('
    return ::rl_asset_finish_task((::rl_handle_t)task);
  ')
  static function finishNative(task: RLHandle): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_asset_get_task_path((::rl_handle_t)task);
  ')
  static function getPathNative(task: RLHandle): String {
    return null;
  }

  @:functionCode('
    unsigned char *data_ptr = nullptr;
    size_t size = 0;
    int rc = ::rl_fs_read(filename.utf8_str(), &data_ptr, &size);
    if (rc != 0 || data_ptr == nullptr) {
      ::rl_fs_read_free(data_ptr);
      return null();
    }
    Array<unsigned char> data = Array_obj<unsigned char>::__new((int)size, (int)size);
    if (size > 0) {
      ::memcpy(data->GetBase(), data_ptr, size);
    }
    ::rl_fs_read_free(data_ptr);
    return data;
  ')
  static function readBytesData(filename: String): haxe.io.BytesData {
    return null;
  }

  static function readNative(filename: String): haxe.io.Bytes {
    var data = readBytesData(filename);
    if (data == null) return null;
    return haxe.io.Bytes.ofData(data);
  }

  @:functionCode('
    ::rl_fs_write(path.utf8_str(), (const unsigned char *)data->GetBase(), (size_t)data->length);
  ')
  static function writeNative(path: String, data: haxe.io.BytesData): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_remove(filename.utf8_str());
  ')
  static function removeNative(filename: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_mkdir(path.utf8_str());
  ')
  static function mkdirNative(path: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_rmdir(path.utf8_str());
  ')
  static function rmdirNative(path: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fs_clear();
  ')
  static function clearNative(): Int {
    return 0;
  }

  @:functionCode('
    ::rl_asset_free_task((::rl_handle_t)task);
  ')
  static function freeNative(task: RLHandle): Void {}

  @:functionCode('
    return ::rl_asset_add_task((::rl_handle_t)task, onSuccess, onFailure, userData);
  ')
  static function addTaskNative(task: RLHandle,
    onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_asset_set_host(assetHost.utf8_str());
  ')
  static function setAssetHostNative(assetHost: String): Int {
    return -1;
  }

  @:functionCode('
    return ::rl_asset_get_host();
  ')
  static function getAssetHostNative(): String {
    return null;
  }

  @:functionCode('
    return ::rl_asset_ping_host(assetHost.utf8_str());
  ')
  static function pingAssetHostNative(assetHost: String): Float {
    return -1.0;
  }

  @:functionCode('
    return ::rl_fs_get_root_dir();
  ')
  static function getBaseDirNative(): String {
    return null;
  }

  @:functionCode('
    return ::rl_fs_exists(filename.utf8_str());
  ')
  static function existsNative(filename: String): Bool {
    return false;
  }

  @:functionCode('
    ::rl_asset_tick();
  ')
  static function tickNative(): Void {}

  // Public API

  public static function fsInit(?baseDir: String): Int {
    return initNative(baseDir == null ? "" : baseDir);
  }

  public static function fsInitAsync(?baseDir: String): Int {
    return initAsyncNative(baseDir == null ? "" : baseDir);
  }

  public static function fsDeinit(): Void {
    deinitNative();
  }

  public static function fsDeinitAsync(): RLHandle {
    return deinitAsyncNative();
  }

  public static function fsIsInitialized(): Bool {
    return isInitializedNative();
  }

  public static function fsIsReady(): Bool {
    return isReadyNative();
  }

  public static function fsFlush(): Int {
    return flushNative();
  }

  public static function fsRestoreAsync(): RLHandle {
    return restoreAsyncNative();
  }

  public static function assetEnsureAsync(localPath: String, ?src: String): RLHandle {
    return ensureAsyncNative(localPath, src == null ? "" : src);
  }

  public static function assetEnsure(localPath: String, ?src: String): Int {
    return ensureNative(localPath, src == null ? "" : src);
  }

  public static function assetEnsureGroupAsync(filenames: Array<String>): RLHandle {
    return cast ensureGroupAsyncNative(filenames);
  }

  public static function assetPollTask(task: RLHandle): Bool {
    return pollNative(task);
  }

  public static function assetFinishTask(task: RLHandle): Int {
    return finishNative(task);
  }

  public static function assetGetTaskPath(task: RLHandle): String {
    return getPathNative(task);
  }

  public static function fsRead(filename: String): haxe.io.Bytes {
    return readNative(filename);
  }

  public static function fsWrite(path: String, bytes: haxe.io.Bytes): Int {
    if (bytes == null) return -1;
    return writeNative(path, bytes.getData());
  }

  public static function fsRemove(filename: String): Int {
    return removeNative(filename);
  }

  public static function fsMkdir(path: String): Int {
    return mkdirNative(path);
  }

  public static function fsRmdir(path: String): Int {
    return rmdirNative(path);
  }

  public static function fsClear(): Int {
    return clearNative();
  }

  public static function assetFreeTask(task: RLHandle): Void {
    freeNative(task);
  }

  public static function fsExists(filename: String): Bool {
    return existsNative(filename);
  }

  public static function assetAddTask(task: RLHandle,
    onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return addTaskNative(task, onSuccess, onFailure, userData);
  }

  public static function assetPingHost(?assetHost: String): Float {
    return pingAssetHostNative(assetHost == null ? "" : assetHost);
  }

  public static function assetSetHost(assetHost: String): Int {
    return setAssetHostNative(assetHost);
  }

  public static function assetGetHost(): String {
    return getAssetHostNative();
  }

  public static function fsGetRootDir(): String {
    return getBaseDirNative();
  }

  @:functionCode('
    char buf[4096];
    ::rl_fs_normalize_path(path.utf8_str(), buf, sizeof(buf));
    return ::String(buf);
  ')
  static function normalizePathNative(path: String): String {
    return "";
  }

  public static function fsNormalizePath(path: String): String {
    return normalizePathNative(path == null ? "" : path);
  }

  public static function assetTick(): Void {
    tickNative();
  }
}
#end
