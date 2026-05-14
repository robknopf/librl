/**
 * Call a runtime entrypoint that may live on either:
 * - a **plain JS / ESM exports object** (`mod._rt_boot` etc.), or
 * - an **Emscripten `Module`** (`ccall` only, or both).
 *
 * Resolution order: **`mod[name]` if it is a function**, else **`mod.ccall(...)`**.
 *
 * **Emscripten / JSPI:** the 5th `ccall` argument is `{ async: true }` when `ccallOpts` is
 * **`undefined`** (default). Use **`ccallOpts: null`** for a **sync** `ccall` (no 5th arg).
 * Any other object is passed through as the 5th argument.
 *
 * **Return value:** thenables are awaited (async JS or Promising `ccall`).
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

export async function startRuntime(mod, label = "runtime") {
  let stopped = false;
  let runtimeTickerId = 0;
  let lastFrameTimeMs = 0;

  async function stopRuntime() {
    if (stopped) {
      return;
    }

    stopped = true;
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

  if ((await callRuntime(mod, "_rt_boot", "number", [], [], undefined)) !== 0) {
    throw new Error(`${label}: rt_boot failed`);
  }
  if ((await callRuntime(mod, "_rt_init", "number", ["number"], [0], undefined)) !== 0) {
    throw new Error(`${label}: rt_init failed`);
  }

  runtimeTickerId = window.requestAnimationFrame(tickRuntime);
  return stopRuntime;
}
