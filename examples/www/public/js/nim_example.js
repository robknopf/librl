import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Nim", "examples/nim/out/wasm/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "nim"),
});
