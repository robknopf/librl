import { runExample } from "./example_runner.js";

function callMaybeAsync(result) {
  if (result && typeof result.then === "function") {
    return result;
  }
  return Promise.resolve(result);
}

async function startHaxeSimple(mod) {
  let stopped = false;
  let frameId = 0;
  let lastFrameTimeMs = 0;

  function stop() {
    if (stopped) {
      return;
    }
    stopped = true;
    if (frameId) {
      window.cancelAnimationFrame(frameId);
      frameId = 0;
    }
    try {
      mod.ccall("example_shutdown", null, [], []);
    } catch (err) {
      console.error("haxe-simple: example_shutdown failed", err);
    }
  }

  async function frame(frameTimeMs) {
    const dt = lastFrameTimeMs === 0 ? 0 : Math.max(0, (frameTimeMs - lastFrameTimeMs) / 1000.0);
    lastFrameTimeMs = frameTimeMs;
    if (stopped) {
      return;
    }

    const rc = await callMaybeAsync(mod._example_frame(dt));
    if (rc < 0) {
      console.error(`haxe-simple: example_frame failed with ${rc}`);
      stop();
      return;
    }
    if (rc > 0) {
      stop();
      return;
    }
    frameId = window.requestAnimationFrame(frame);
  }

  window.addEventListener("beforeunload", stop, { once: true });
  if ((await callMaybeAsync(mod._example_init())) !== 0) {
    throw new Error("haxe-simple: example_init failed");
  }
  frameId = window.requestAnimationFrame(frame);
  return stop;
}

runExample("Haxe", "examples/haxe-simple/out/wasm/Main.js", {
  onModuleReady: startHaxeSimple,
});
