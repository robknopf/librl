import { runExample } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";

// testing using genes instead of stock monolithic js
// note that instead of a default export, genes exports the module name
// so we create a shim adapter to return it like a plain object
/*
runExample("Haxe Simple (js)", "js/haxe_js_simple_genes_adapter.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-js-simple"),
});
*/

/* use the generated haxe directly. This is a plain object */
runExample("Haxe Simple (js)", "examples/haxe-simple/out/js/main-js-simple.js", {
  onModuleReady: (mod) => startRuntime(mod, "haxe-js-simple"),
});
