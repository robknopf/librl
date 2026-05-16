
import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";


runExample("Haxe Simple (js)", "examples/cppia/out/wasm/ScriptableMain.js", {
  onModuleReady: (mod) => startRuntime(mod, "cppia"),
});
