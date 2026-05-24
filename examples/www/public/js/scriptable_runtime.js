/**
 * Scriptable springboard: presents `_rt_*` to `runtime_host.js` while loading reloadable
 * compiled script ESMs (Nim + `include runtime`, future Haxe with same ABI).
 *
 * Script module contract:
 *   `_rt_boot`, `_rt_init`, `_rt_tick`, `_rt_shutdown` — runtime ABI (script owns RL)
 *   `onLoad(stashed)`, `onUnload()` — hot-reload hooks (host calls between ticks)
 *
 * First mount: `_rt_boot` → `_rt_init` → `onLoad`.
 * Reload: `onUnload` → import new module → `_rt_boot` (re-bind; wasm stays up) → `onLoad`.
 *
 * Query params (optional):
 *   script   — asset path under public/ (default: assets/scripts/nim/js/main.js)
 *   watcher  — script_watcher WebSocket URL (default: ws://<host>:9001/ws)
 */

const RT_SUCCESS = 0;
const RT_FAILED = -1;
const RT_STOPPED = 1;

const DEFAULT_SCRIPT_ASSET = "assets/scripts/nim/js/main.js";

function getPageBase() {
  return new URL(".", window.location.href);
}

function parseConfig() {
  const params = new URLSearchParams(window.location.search);
  const scriptAsset = params.get("script") ?? DEFAULT_SCRIPT_ASSET;
  const pageBase = getPageBase();
  const scriptModuleUrl = new URL(scriptAsset, pageBase).href;

  let watcherUrl = params.get("watcher");
  if (!watcherUrl) {
    watcherUrl = `ws://${window.location.hostname}:9001/ws`;
  }

  const watchDir = scriptAsset.includes("/")
    ? scriptAsset.slice(0, scriptAsset.lastIndexOf("/"))
    : "assets/scripts";

  return {
    scriptAsset,
    scriptModuleUrl,
    watcherUrl,
    watchDir,
  };
}

const config = parseConfig();

/** @type {Record<string, unknown> | null} */
let scriptMod = null;
/** @type {unknown} */
let stashed = null;
/** @type {boolean} */
let sessionInitialized = false;
/** @type {WebSocket | null} */
let scriptWatcher = null;
/** @type {boolean} */
let reloadScheduled = false;
/** @type {boolean} */
let reloadInProgress = false;

async function awaitResult(value) {
  if (value != null && typeof value.then === "function") {
    return await value;
  }
  return value;
}

async function callExport(mod, name, ...args) {
  const fn = mod?.[name];
  if (typeof fn !== "function") {
    throw new Error(`[scriptable] ${config.scriptAsset} missing export ${name}()`);
  }
  return await awaitResult(fn.apply(mod, args));
}

function assertRuntimeModule(mod) {
  if (typeof mod?._rt_boot !== "function") {
    throw new Error(
      `[scriptable] ${config.scriptAsset} must export _rt_boot (compiled script with include runtime)`,
    );
  }
}

async function loadScriptModule() {
  const url = `${config.scriptModuleUrl}?t=${Date.now()}`;
  const mod = await import(/* @vite-ignore */ url);
  const exp = mod.default ?? mod;
  assertRuntimeModule(exp);
  return exp;
}

async function bindScriptModule(mod) {
  const bootRc = await callExport(mod, "_rt_boot");
  if (bootRc !== RT_SUCCESS) {
    throw new Error(`[scriptable] _rt_boot failed (${bootRc})`);
  }
}

async function mountScript() {
  if (!sessionInitialized) {
    const initRc = await callExport(scriptMod, "_rt_init", 0);
    if (initRc !== RT_SUCCESS) {
      throw new Error(`[scriptable] _rt_init failed (${initRc})`);
    }
    sessionInitialized = true;
  }
  const loadRc = await callExport(scriptMod, "onLoad", stashed);
  if (loadRc !== RT_SUCCESS) {
    throw new Error(`[scriptable] onLoad failed (${loadRc})`);
  }
  stashed = null;
}

async function reloadScript() {
  if (reloadInProgress) {
    return;
  }
  reloadInProgress = true;
  try {
    console.log(`[scriptable] reloading ${config.scriptAsset}`);
    if (scriptMod != null) {
      stashed = (await callExport(scriptMod, "onUnload")) ?? null;
    }
    scriptMod = await loadScriptModule();
    await bindScriptModule(scriptMod);
    await mountScript();
    console.log(`[scriptable] reload complete (${config.scriptAsset})`);
  } catch (err) {
    console.error("[scriptable] reload failed:", err);
  } finally {
    reloadInProgress = false;
    reloadScheduled = false;
  }
}

function scheduleReload() {
  if (reloadScheduled || reloadInProgress || !sessionInitialized) {
    return;
  }
  reloadScheduled = true;
}

function connectScriptWatcher() {
  if (!config.watcherUrl) {
    return;
  }

  console.log(`[script_watcher] connecting to ${config.watcherUrl}`);
  scriptWatcher = new WebSocket(config.watcherUrl);

  scriptWatcher.addEventListener("open", () => {
    console.log(
      `[script_watcher] connected; watching ${config.watchDir} (*.js) for ${config.scriptAsset}`,
    );
    scriptWatcher.send(
      JSON.stringify({
        type: "watch",
        data: {
          watch: [{ dir: config.watchDir, ext: ".js", recursive: true }],
        },
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
      if (path !== config.scriptAsset) {
        console.debug(`[script_watcher] ignoring ${path} (watching ${config.scriptAsset})`);
        return;
      }
      console.log(`[script_watcher] file_changed: ${path}`);
      scheduleReload();
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

const runtime = {
  async _rt_boot() {
    console.log(`[scriptable] script=${config.scriptAsset}`);
    connectScriptWatcher();
    try {
      scriptMod = await loadScriptModule();
      await bindScriptModule(scriptMod);
      return RT_SUCCESS;
    } catch (err) {
      console.error("[scriptable] rt_boot failed:", err);
      return RT_FAILED;
    }
  },

  async _rt_init(_hostData) {
    try {
      await mountScript();
      return RT_SUCCESS;
    } catch (err) {
      console.error("[scriptable] rt_init failed:", err);
      return RT_FAILED;
    }
  },

  async _rt_tick(dt) {
    if (reloadScheduled) {
      await reloadScript();
    }

    if (scriptMod == null) {
      return RT_SUCCESS;
    }

    try {
      const rc = await callExport(scriptMod, "_rt_tick", dt);
      if (rc === RT_STOPPED || rc === RT_FAILED) {
        return rc;
      }
      return RT_SUCCESS;
    } catch (err) {
      console.error("[scriptable] _rt_tick failed:", err);
      return RT_FAILED;
    }
  },

  async _rt_shutdown() {
    disconnectScriptWatcher();
    if (scriptMod != null) {
      try {
        await callExport(scriptMod, "_rt_shutdown");
      } catch (err) {
        console.error("[scriptable] rt_shutdown failed:", err);
      }
    }
    scriptMod = null;
    stashed = null;
    sessionInitialized = false;
  },
};

export default runtime;
