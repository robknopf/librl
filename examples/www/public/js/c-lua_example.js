import { runExample } from "./example_runner.js";

function startLuaFramePump(mod) {
  let stopped = false;
  let frameRequestId = 0;

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
      mod.ccall("rl_stop", null, [], []);
    } catch (err) {
      console.error("c-lua shutdown failed", err);
    }
  }

  window.addEventListener("beforeunload", stopFramePump, { once: true });

  async function frame() {
    let rc = 0;

    if (stopped) {
      return;
    }

    try {
      rc = await mod.ccall("rl_tick", "number", [], [], { async: true });
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

  frameRequestId = window.requestAnimationFrame(frame);
  return stopFramePump;
}

runExample("C-Lua", "examples/c-lua/out/main.js", {
  onModuleReady: startLuaFramePump,
});
