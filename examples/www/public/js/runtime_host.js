export function callMaybeAsync(result) {
  if (result && typeof result.then === "function") {
    return result;
  }
  return Promise.resolve(result);
}

export async function startRuntime(mod, label = "runtime") {
  let stopped = false;
  let runtimeTickerId = 0;
  let lastFrameTimeMs = 0;

  function stopRuntime() {
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
      rc = await callMaybeAsync(mod._rt_tick(dt));
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

  if ((await callMaybeAsync(mod._rt_boot())) !== 0) {
    throw new Error(`${label}: rt_boot failed`);
  }
  if ((await callMaybeAsync(mod._rt_init(0))) !== 0) {
    throw new Error(`${label}: rt_init failed`);
  }

  runtimeTickerId = window.requestAnimationFrame(tickRuntime);
  return stopRuntime;
}
