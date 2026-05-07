import { runExample } from "./example_runner.js";

function callMaybeAsync(result) {
  if (result && typeof result.then === "function") {
    return result;
  }
  return Promise.resolve(result);
}

async function startRuntime(mod) {
  let stopped = false;
  let runtimeTickerId = 0;
  let lastFrameTimeMs = 0;

  function stopRuntimeTicker() {
    if (stopped) {
      return;
    }

    stopped = true;
    if (runtimeTickerId) {
      window.cancelAnimationFrame(runtimeTickerId);
      runtimeTickerId = 0;
    }

    try {
      mod.ccall("rt_shutdown", null, [], []);
    } catch (err) {
      console.error("c-lua shutdown failed", err);
    }
  }

  window.addEventListener("beforeunload", stopRuntimeTicker, { once: true });

  async function tickRuntime(frameTimeMs) {
    let rc = 0;
    const dt = lastFrameTimeMs === 0 ? 0 : Math.max(0, (frameTimeMs - lastFrameTimeMs) / 1000.0);
    lastFrameTimeMs = frameTimeMs;

    if (stopped) {
      return;
    }

    try {
      rc = await callMaybeAsync(mod._rt_tick(dt));
    } catch (err) {
      stopRuntimeTicker();
      console.error(`c-lua: rt_tick(${dt}) failed: `, err);
      throw err;
    }

    if (rc !== 0) {
      stopRuntimeTicker();
      return;
    }

    if (!stopped) {
      runtimeTickerId = window.requestAnimationFrame(tickRuntime);
    }
  }

  if ((await callMaybeAsync(mod._rt_boot())) !== 0) {
    throw new Error("rt_boot failed");
  }
  if ((await callMaybeAsync(mod._rt_init(0))) !== 0) {
    throw new Error("rt_init failed");
  }

  runtimeTickerId = window.requestAnimationFrame(tickRuntime);
  return stopRuntimeTicker;
}

runExample("C-Lua", "examples/c-lua/out/main.js", {
  onModuleReady: startRuntime,
});
