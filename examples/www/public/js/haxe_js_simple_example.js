import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Haxe Simple (js)", "examples/haxe-simple/out/js/main-js-simple.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-js-simple"),
});
