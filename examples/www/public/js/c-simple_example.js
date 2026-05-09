import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("C-simple", "examples/c-simple/out/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "c-simple"),
});
