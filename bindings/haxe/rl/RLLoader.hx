package rl;

import rl.RL.RLLoaderTask;

#if cpp
@:headerInclude("rl_loader.h")
@:headerInclude("alloca.h")
class RLLoader {
  @:functionCode("
    int n = filenames->length;
    const char **ptrs = (const char **)alloca(n * sizeof(const char *));
    for (int i = 0; i < n; i++) ptrs[i] = filenames->__get(i).utf8_str();
    return rl_loader_import_assets_async((const char *const *)ptrs, (size_t)n);
  ")
  public static function importAssetsAsync(filenames: Array<String>): cpp.RawPointer<RLLoaderTask> {
    return null;
  }
}
#end
