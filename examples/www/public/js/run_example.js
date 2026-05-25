import { runExample, instantiateRuntimeModule } from "./example_runner.js";
import { startRuntime } from "./runtime_host.js";
import { getExample } from "./example_catalog.js";

const params = new URLSearchParams(window.location.search);
const key = params.get("example");
const entry = getExample(key);

if (!entry) {
  throw new Error(`Unknown example: ${key ?? "(missing)"}`);
}

if (entry.standalone) {
  const moduleUrl = new URL(entry.module, window.location.href).href;
  import(/* @vite-ignore */ moduleUrl);
} else {
  const watcherOverride = params.get("watcher");

  runExample(entry.label, entry.module, {
    buildEnv: entry.buildEnv,
    onModuleReady: (mod, ctx) =>
      startRuntime(mod, key, {
        watchedPaths: entry.watchedPaths,
        scriptModuleUrl: ctx.moduleUrl,
        reloadModule: () => instantiateRuntimeModule(ctx.moduleUrl, entry.buildEnv),
        watcherUrl: watcherOverride ?? undefined,
      }),
  });
}
