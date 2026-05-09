import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("C-Lua", "examples/c-lua/out/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "c-lua"),
});
