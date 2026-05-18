/**
 * hxcpp-only fileio implementation.
 * Contains the internal RLFileio class used by RLImpl.cpp.hx.
 * Never imported directly by scripts.
 */
package rl.impl;

#if cpp
import rl.RLHandle;

typedef RLFileioCallbackFn = cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>;

@:keep
@:headerInclude("rl_fileio.h")
@:headerInclude("alloca.h")
@:headerInclude("stdint.h")
@:headerInclude("string.h")
class RLFileio {
  @:functionCode('
    return ::rl_fileio_init(baseDir.length == 0 ? (const char *)0 : baseDir.utf8_str());
  ')
  static function initNative(baseDir: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_init_async(baseDir.length == 0 ? (const char *)0 : baseDir.utf8_str());
  ')
  static function initAsyncNative(baseDir: String): Int {
    return 0;
  }

  @:functionCode('
    ::rl_fileio_deinit();
  ')
  static function deinitNative(): Void {}

  @:functionCode('
    return (int)::rl_fileio_deinit_async();
  ')
  static function deinitAsyncNative(): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_is_initialized();
  ')
  static function isInitializedNative(): Bool { return false; }

  @:functionCode('
    return ::rl_fileio_is_ready();
  ')
  static function isReadyNative(): Bool { return false; }

  @:functionCode('
    return ::rl_fileio_flush();
  ')
  static function flushNative(): Int { return 0; }

  @:functionCode('
    return (int)::rl_fileio_restore_async();
  ')
  static function restoreAsyncNative(): RLHandle {
    return 0;
  }

  @:functionCode('
    return (int)::rl_fileio_ensure_async(
      localPath.utf8_str(),
      src.length == 0 ? (const char *)0 : src.utf8_str()
    );
  ')
  static function ensureAsyncNative(localPath: String, src: String): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_ensure(
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
    return (int)::rl_fileio_ensure_group_async((const char *const *)ptrs, (size_t)n);
  ')
  static function ensureGroupAsyncNative(filenames: Array<String>): RLHandle {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_poll((::rl_handle_t)task);
  ')
  static function pollNative(task: RLHandle): Bool {
    return false;
  }

  @:functionCode('
    return ::rl_fileio_finish((::rl_handle_t)task);
  ')
  static function finishNative(task: RLHandle): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_get_path((::rl_handle_t)task);
  ')
  static function getPathNative(task: RLHandle): String {
    return null;
  }

  @:functionCode('
    unsigned char *data_ptr = nullptr;
    size_t size = 0;
    int rc = ::rl_fileio_read(filename.utf8_str(), &data_ptr, &size);
    if (rc != 0 || data_ptr == nullptr) {
      ::rl_fileio_read_free(data_ptr);
      return null();
    }
    Array<unsigned char> data = Array_obj<unsigned char>::__new((int)size, (int)size);
    if (size > 0) {
      ::memcpy(data->GetBase(), data_ptr, size);
    }
    ::rl_fileio_read_free(data_ptr);
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
    ::rl_fileio_write(path.utf8_str(), (const unsigned char *)data->GetBase(), (size_t)data->length);
  ')
  static function writeNative(path: String, data: haxe.io.BytesData): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_remove(filename.utf8_str());
  ')
  static function removeNative(filename: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_mkdir(path.utf8_str());
  ')
  static function mkdirNative(path: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_rmdir(path.utf8_str());
  ')
  static function rmdirNative(path: String): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_clear();
  ')
  static function clearNative(): Int {
    return 0;
  }

  @:functionCode('
    ::rl_fileio_free((::rl_handle_t)task);
  ')
  static function freeNative(task: RLHandle): Void {}

  @:functionCode('
    return ::rl_fileio_add_task((::rl_handle_t)task, onSuccess, onFailure, userData);
  ')
  static function addTaskNative(task: RLHandle,
    onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return 0;
  }

  @:functionCode('
    return ::rl_fileio_ping_asset_host(assetHost.utf8_str());
  ')
  static function pingAssetHostNative(assetHost: String): Float {
    return -1.0;
  }

  @:functionCode('
    return ::rl_fileio_get_base_dir();
  ')
  static function getBaseDirNative(): String {
    return null;
  }

  @:functionCode('
    return ::rl_fileio_exists(filename.utf8_str());
  ')
  static function existsNative(filename: String): Bool {
    return false;
  }

  @:functionCode('
    ::rl_fileio_tick();
  ')
  static function tickNative(): Void {}

  // Public API

  public static function fileioInit(?baseDir: String): Int {
    return initNative(baseDir == null ? "" : baseDir);
  }

  public static function fileioInitAsync(?baseDir: String): Int {
    return initAsyncNative(baseDir == null ? "" : baseDir);
  }

  public static function fileioDeinit(): Void {
    deinitNative();
  }

  public static function fileioDeinitAsync(): RLHandle {
    return deinitAsyncNative();
  }

  public static function fileioIsInitialized(): Bool {
    return isInitializedNative();
  }

  public static function fileioIsReady(): Bool {
    return isReadyNative();
  }

  public static function fileioFlush(): Int {
    return flushNative();
  }

  public static function fileioRestoreAsync(): RLHandle {
    return restoreAsyncNative();
  }

  public static function fileioEnsureAsync(localPath: String, ?src: String): RLHandle {
    return ensureAsyncNative(localPath, src == null ? "" : src);
  }

  public static function fileioEnsure(localPath: String, ?src: String): Int {
    return ensureNative(localPath, src == null ? "" : src);
  }

  public static function fileioEnsureGroupAsync(filenames: Array<String>): RLHandle {
    return cast ensureGroupAsyncNative(filenames);
  }

  public static function fileioPoll(task: RLHandle): Bool {
    return pollNative(task);
  }

  public static function fileioFinish(task: RLHandle): Int {
    return finishNative(task);
  }

  public static function fileioGetPath(task: RLHandle): String {
    return getPathNative(task);
  }

  public static function fileioRead(filename: String): haxe.io.Bytes {
    return readNative(filename);
  }

  public static function fileioWrite(path: String, bytes: haxe.io.Bytes): Int {
    if (bytes == null) return -1;
    return writeNative(path, bytes.getData());
  }

  public static function fileioRemove(filename: String): Int {
    return removeNative(filename);
  }

  public static function fileioMkdir(path: String): Int {
    return mkdirNative(path);
  }

  public static function fileioRmdir(path: String): Int {
    return rmdirNative(path);
  }

  public static function fileioClear(): Int {
    return clearNative();
  }

  public static function fileioFree(task: RLHandle): Void {
    freeNative(task);
  }

  public static function fileioExists(filename: String): Bool {
    return existsNative(filename);
  }

  public static function fileioAddTask(task: RLHandle,
    onSuccess: RLFileioCallbackFn, onFailure: RLFileioCallbackFn,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return addTaskNative(task, onSuccess, onFailure, userData);
  }

  public static function fileioPingAssetHost(?assetHost: String): Float {
    return pingAssetHostNative(assetHost == null ? "" : assetHost);
  }

  public static function fileioGetBaseDir(): String {
    return getBaseDirNative();
  }

  public static function fileioTick(): Void {
    tickNative();
  }
}
#end
