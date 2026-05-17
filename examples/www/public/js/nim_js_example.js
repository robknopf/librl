import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Nim (js)", "examples/nim/out/js/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "nim-js"),
});
