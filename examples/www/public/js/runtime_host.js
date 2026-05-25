/**
 * Generic runtime host: drives any module that exports `_rt_*`.
 *
 * Lifecycle:
 *   _rt_boot → _rt_init → _rt_load(null) → _rt_tick…
 *   watched: _rt_unload → re-import module → _rt_boot → _rt_load(stash)  (skip _rt_init)
 *   teardown: _rt_shutdown
 *
 * Callable via plain ESM exports or Emscripten `ccall` (JSPI when `ccallOpts` is undefined).
 */

const RT_SUCCESS = 0;

/** Coalesce double-writes from Haxe MakeESM before swapping watched modules. */
const RELOAD_DEBOUNCE_MS = 450;

/**
 * @param {unknown} module
 * @param {string} name
 * @param {string | null} returnType
 * @param {string[]} argTypes
 * @param {unknown[]} args
 * @param {object | null | undefined} ccallOpts
 */
export async function callRuntime(module, name, returnType, argTypes, args, ccallOpts) {
  let result;
  const direct = module != null && typeof module[name] === "function" ? module[name] : null;
  if (direct != null) {
    result = direct.apply(module, args);
  } else if (typeof module?.ccall === "function") {
    if (ccallOpts === null) {
      result = module.ccall(name, returnType, argTypes, args);
    } else if (ccallOpts !== undefined) {
      result = module.ccall(name, returnType, argTypes, args, ccallOpts);
    } else {
      result = module.ccall(name, returnType, argTypes, args, { async: true });
    }
  } else {
    throw new Error(`Runtime function '${name}' not found (no ${name} on module and no ccall)`);
  }

  if (result != null && typeof result.then === "function") {
    return await result;
  }
  return result;
}

/**
 * @param {unknown} module
 * @param {string} name
 * @param {unknown} fallback
 */
async function callRuntimeOptional(module, name, fallback, returnType, argTypes, args, ccallOpts) {
  if (module != null && typeof module[name] === "function") {
    return await callRuntime(module, name, returnType, argTypes, args, ccallOpts);
  }
  if (typeof module?.ccall === "function") {
    try {
      return await callRuntime(module, name, returnType, argTypes, args, ccallOpts);
    } catch {
      return fallback;
    }
  }
  return fallback;
}

/**
 * @param {unknown} initialMod
 * @param {string} label
 * @param {{
 *   watchedPaths?: Array<{ dir: string, ext: string, recursive?: boolean }>,
 *   scriptModuleUrl?: string,
 *   reloadModule?: () => Promise<unknown>,
 *   watcherUrl?: string,
 * }} [options]
 */
export async function startRuntime(initialMod, label = "runtime", options = {}) {
  let mod = initialMod;
  let stopped = false;
  let runtimeTickerId = 0;
  let lastFrameTimeMs = 0;
  let sessionInitialized = false;
  let stashed = null;

  const watchedPaths = Array.isArray(options.watchedPaths) ? options.watchedPaths : [];
  const hotReload = watchedPaths.length > 0;
  const scriptModuleUrl = options.scriptModuleUrl;
  const reloadModule = options.reloadModule;
  const watcherUrl =
    options.watcherUrl ?? `wss://${window.location.hostname}:9001/ws`;

  let scriptWatcher = null;
  let reloadScheduled = false;
  let reloadInProgress = false;
  /** @type {ReturnType<typeof setTimeout> | null} */
  let reloadDebounceTimer = null;
  let reloadQueued = false;

  async function importRuntimeModule() {
    if (reloadModule) {
      return await reloadModule();
    }
    if (!scriptModuleUrl) {
      throw new Error(`[${label}] watched example missing scriptModuleUrl`);
    }
    const imported = await import(/* @vite-ignore */ `${scriptModuleUrl}?t=${Date.now()}`);
    const exp = imported.default ?? imported;
    if (typeof exp?._rt_boot !== "function") {
      throw new Error(`[${label}] runtime module must export _rt_boot`);
    }
    return exp;
  }

  async function swapRuntimeModule() {
    if (reloadInProgress) {
      return;
    }
    reloadInProgress = true;
    try {
      console.log(`[${label}] reloading module ${scriptModuleUrl}`);
      if (mod != null) {
        const unloadResult = await callRuntime(mod, "_rt_unload", null, [], [], null);
        stashed = unloadResult ?? null;
      }
      mod = await importRuntimeModule();
      const bootRc = await callRuntime(mod, "_rt_boot", "number", [], [], undefined);
      if (bootRc !== RT_SUCCESS) {
        throw new Error(`_rt_boot failed (${bootRc})`);
      }
      const loadRc = await callRuntime(
        mod,
        "_rt_load",
        "number",
        [],
        [stashed ?? null],
        null,
      );
      if (loadRc !== RT_SUCCESS) {
        throw new Error(`_rt_load failed (${loadRc})`);
      }
      stashed = null;
      console.log(`[${label}] reload complete`);
    } catch (err) {
      console.error(`[${label}] reload failed:`, err);
    } finally {
      reloadInProgress = false;
      reloadScheduled = false;
      if (reloadQueued) {
        reloadQueued = false;
        scheduleSwap();
      }
    }
  }

  function scheduleSwap() {
    if (!sessionInitialized || !hotReload) {
      return;
    }
    if (reloadInProgress) {
      reloadQueued = true;
      return;
    }
    if (reloadDebounceTimer) {
      clearTimeout(reloadDebounceTimer);
    }
    reloadDebounceTimer = setTimeout(() => {
      reloadDebounceTimer = null;
      if (reloadScheduled || reloadInProgress) {
        reloadQueued = true;
        return;
      }
      reloadScheduled = true;
    }, RELOAD_DEBOUNCE_MS);
  }

  function connectScriptWatcher() {
    if (!hotReload) {
      return;
    }

    console.log(`[script_watcher] connecting to ${watcherUrl}`);
    scriptWatcher = new WebSocket(watcherUrl);

    scriptWatcher.addEventListener("open", () => {
      console.log(`[script_watcher] connected; watching`, watchedPaths);
      scriptWatcher.send(
        JSON.stringify({
          type: "watch",
          data: { watch: watchedPaths },
        }),
      );
    });

    scriptWatcher.addEventListener("message", (event) => {
      try {
        const msg = JSON.parse(String(event.data));
        if (msg.type !== "file_changed") {
          return;
        }
        const path = msg.data?.path;
        console.log(`[script_watcher] file_changed: ${path}`);
        scheduleSwap();
      } catch (err) {
        console.debug("[script_watcher] message ignored:", err);
      }
    });

    scriptWatcher.addEventListener("error", () => {
      console.error(
        "[script_watcher] WebSocket error (mixed content, host, or port — check DevTools → Network → WS)",
      );
    });

    scriptWatcher.addEventListener("close", (event) => {
      console.debug(`[script_watcher] closed code=${event.code} reason=${event.reason}`);
      scriptWatcher = null;
    });
  }

  function disconnectScriptWatcher() {
    if (scriptWatcher) {
      scriptWatcher.close();
      scriptWatcher = null;
    }
  }

  async function stopRuntime() {
    if (stopped) {
      return;
    }

    stopped = true;
    disconnectScriptWatcher();
    if (reloadDebounceTimer) {
      clearTimeout(reloadDebounceTimer);
      reloadDebounceTimer = null;
    }
    if (runtimeTickerId) {
      window.cancelAnimationFrame(runtimeTickerId);
      runtimeTickerId = 0;
    }

    try {
      await callRuntime(mod, "_rt_shutdown", null, [], [], undefined);
    } catch (err) {
      console.error(`${label}: rt_shutdown failed`, err);
    }
  }

  window.addEventListener("beforeunload", stopRuntime, { once: true });

  async function tickRuntime(frameTimeMs) {
    let rc = 0;
    const dt = lastFrameTimeMs === 0 ? 0 : Math.max(0, (frameTimeMs - lastFrameTimeMs) / 1000.0);
    lastFrameTimeMs = frameTimeMs;

    if (stopped) {
      return;
    }

    if (reloadScheduled) {
      await swapRuntimeModule();
    }

    try {
      rc = await callRuntime(mod, "_rt_tick", "number", ["number"], [dt], undefined);
    } catch (err) {
      stopRuntime();
      console.error(`${label}: rt_tick(${dt}) failed`, err);
      throw err;
    }

    if (rc < 0) {
      console.error(`${label}: rt_tick failed with ${rc}`);
      stopRuntime();
      return;
    }
    if (rc > 0) {
      stopRuntime();
      return;
    }

    if (!stopped) {
      runtimeTickerId = window.requestAnimationFrame(tickRuntime);
    }
  }

  if (hotReload) {
    connectScriptWatcher();
  }

  if ((await callRuntime(mod, "_rt_boot", "number", [], [], undefined)) !== RT_SUCCESS) {
    throw new Error(`${label}: rt_boot failed`);
  }
  if ((await callRuntime(mod, "_rt_init", "number", ["number"], [0], undefined)) !== RT_SUCCESS) {
    throw new Error(`${label}: rt_init failed`);
  }
  sessionInitialized = true;

  const loadRc = await callRuntimeOptional(
    mod,
    "_rt_load",
    RT_SUCCESS,
    "number",
    [],
    [null],
    null,
  );
  if (loadRc !== RT_SUCCESS) {
    throw new Error(`${label}: rt_load failed (${loadRc})`);
  }

  runtimeTickerId = window.requestAnimationFrame(tickRuntime);
  return stopRuntime;
}
