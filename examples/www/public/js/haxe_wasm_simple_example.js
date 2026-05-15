
import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";


runExample("Haxe Simple (js)", "examples/haxe-simple/out/wasm/Main.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-wasm-simple"),
});
