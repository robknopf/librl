import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Nim Simple (js)", "examples/nim-simple/out/js/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "nim-js-simple"),
});
