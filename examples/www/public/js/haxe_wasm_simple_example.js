/*
import { runExample } from "./example_runner.js";

function callMaybeAsync(result) {
  if (result && typeof result.then === "function") {
    return result;
  }
  return Promise.resolve(result);
}

async function startHaxeWasmSimple(mod) {
  let stopped = false;
  let frameId = 0;
  let lastFrameTimeMs = 0;

  async function stop() {
    if (stopped) {
      return;
    }
    stopped = true;
    if (frameId) {
      window.cancelAnimationFrame(frameId);
      frameId = 0;
    }
    try {
      await callMaybeAsync(mod._rt_shutdown());

      //mod.ccall("_rt_shutdown", null, [], []);
    } catch (err) {
      console.error("haxe-wasm-simple: rt_shutdown failed", err);
    }
  }

  async function tick(frameTimeMs) {
    const dt = lastFrameTimeMs === 0 ? 0 : Math.max(0, (frameTimeMs - lastFrameTimeMs) / 1000.0);
    lastFrameTimeMs = frameTimeMs;
    if (stopped) {
      return;
    }

    const rc = await callMaybeAsync(mod._rt_tick(dt));
    if (rc < 0) {
      console.error(`haxe-wasm-simple: rt_tick failed with ${rc}`);
      stop();
      return;
    }
    if (rc > 0) {
      stop();
      return;
    }
    frameId = window.requestAnimationFrame(tick);
  }

  window.addEventListener("beforeunload", stop, { once: true });
  if ((await callMaybeAsync(mod._rt_init())) !== 0) {
    throw new Error("haxe-wasm-simple: rt_init failed");
  }
  frameId = window.requestAnimationFrame(tick);
  return stop;
}

runExample("Haxe Simple (wasm)", "examples/haxe-simple/out/wasm/Main.js", {
  onModuleReady: startHaxeWasmSimple,
});
*/

import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";


runExample("Haxe Simple (js)", "examples/haxe-simple/out/wasm/Main.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-wasm-simple"),
});
