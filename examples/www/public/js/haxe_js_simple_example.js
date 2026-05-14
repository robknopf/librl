import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Haxe-JS-Simple", "examples/haxe-js-simple/out/main-js-simple.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-js-simple"),
});
