import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

runExample("Nim Simple", "examples/nim-simple/out/wasm/main.js", {
  onModuleReady: (mod) => startRuntime(mod, "nim-wasm-simple"),
});
