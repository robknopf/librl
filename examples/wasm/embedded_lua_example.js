// Testing C->Wasm example
// Live Server mounts         ["/examples", "./examples"],
// For c->wasm build: cd examples/desktop/c && make wasm-debug-smap
import createExampleModule from "/examples/desktop/c/out/main.debug.smap.js";

(async function () {
  try {
    const canvas = document.getElementById("renderCanvas");
    const mod = await createExampleModule({
      canvas,
      // Keep wasm next to main.js under /example/.
    //  locateFile: (path) => `/c/out/${path}`,
      print: (...args) => console.log("[example]", ...args),
      printErr: (...args) => console.error("[example]", ...args),
    });

    console.log("WASM module initialized:", mod);
    // main() auto-runs by default in this build. If you later add -sNO_INITIAL_RUN=1,
    // uncomment the following line:
    // mod._main(0, 0);
  } catch (e) {
    console.error(e);
  }
})();
