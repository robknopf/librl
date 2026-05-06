import { runExample } from "./example_runner.js";

function startLuaFramePump(mod) {
  let stopped = false;
  let frameRequestId = 0;
  let lastFrameTime = 0;

  function stopFramePump() {
    if (stopped) {
      return;
    }

    stopped = true;
    if (frameRequestId) {
      window.cancelAnimationFrame(frameRequestId);
      frameRequestId = 0;
    }

    try {
      mod.ccall("rt_shutdown", null, [], []);
    } catch (err) {
      console.error("c-lua shutdown failed", err);
    }
  }

  window.addEventListener("beforeunload", stopFramePump, { once: true });

  async function frame(frameTime) {
    let rc = 0;
    const dt = lastFrameTime === 0 ? 0 : Math.max(0, (frameTime - lastFrameTime) / 1000.0);
    lastFrameTime = frameTime;

    if (stopped) {
      return;
    }

    try {
      rc = await mod.ccall("rt_tick", "number", ["number"], [dt], { async: true });
    } catch (err) {
      stopFramePump();
      console.error("c-lua frame pump failed", err);
      throw err;
    }

    if (rc !== 0) {
      stopFramePump();
      return;
    }

    if (!stopped) {
      frameRequestId = window.requestAnimationFrame(frame);
    }
  }

  if (mod.ccall("rt_boot", "number", [], []) !== 0) {
    throw new Error("rt_boot failed");
  }
  if (mod.ccall("rt_init", "number", ["number"], [0]) !== 0) {
    throw new Error("rt_init failed");
  }

  frameRequestId = window.requestAnimationFrame(frame);
  return stopFramePump;
}

runExample("C-Lua", "examples/c-lua/out/main.js", {
  onModuleReady: startLuaFramePump,
});
