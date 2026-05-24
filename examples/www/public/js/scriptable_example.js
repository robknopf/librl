import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Scriptable (js)", "./js/scriptable_runtime.js", {
  onModuleReady: (mod) => startRuntime(mod, "scriptable"),
});
