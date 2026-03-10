/*
import { rl } from "/lib/librl.js";

// load the wasm module
(async function () {
  try {
    await rl.init({ idealWidth: 1024, idealHeight: 1280 });
    const canvas = document.getElementById("renderCanvas");
    const mod = await createExampleModule(getEnv());

    console.log("WASM module initialized:", mod);
    // main() auto-runs by default in this build. If you later add -sNO_INITIAL_RUN=1,
    // uncomment the following line:
    // mod._main(0, 0);
  } catch (e) {
    console.error(e);
  }
})();
*/

// Testing C->Wasm example
// This assumes vite/Live Server has mounted /examples and
// For c->wasm build: cd examples/c && make wasm (or wasm-debug)
import createExampleModule from "/examples/c/out/main.js";

function getEnv() {
  var env = {}

  env.canvas = document.getElementById('renderCanvas');

  var output = document.getElementById('output');
  if (!output) {
    const output = document.createElement("textarea");
    output.id = "output";
    output.style.width = "100%";
    output.style.height = "100px";
    document.body.appendChild(output);
  }

  env.print = function () {
    var e = document.getElementById("output");
    return e && (e.value = ""), function (n) {
      arguments.length > 1 && (n = Array.prototype.slice.call(arguments).join(" ")), console.log(n), e && (e.value += n + "\n", e.scrollTop = e.scrollHeight)
    }
  }();

  env.printErr = function () {
    var e = document.getElementById("output");
    return e && (e.value = ""), function (n) {
      arguments.length > 1 && (n = Array.prototype.slice.call(arguments).join(" ")), console.error(n), e && (e.value += n + "\n", e.scrollTop = e.scrollHeight)
    }
  }();

  return env;
}

function addWindowResizeListener(moduleInstance, idealWidth, idealHeight) {
  // we default to keeping the canvas the same aspect ratio as the ideal dimensions
  idealWidth = idealWidth || 1024;
  idealHeight = idealHeight || 1280;
  var aspectRatio = idealWidth / idealHeight;

  window.addEventListener('resize', (_event) => {
    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;

    let newWidth, newHeight;
    if (windowWidth / windowHeight > aspectRatio) {
      newHeight = windowHeight;
      newWidth = windowHeight * aspectRatio;
    } else {
      newWidth = windowWidth;
      newHeight = windowWidth / aspectRatio;
    }

    moduleInstance.ccall(
      "rl_set_window_size",
      null,
      ["number", "number"],
      [newWidth, newHeight]
    );
  });

  // force an initial resize event
  window.dispatchEvent(new Event('resize'));
}

// load the wasm module
(async function () {
  try {
    const canvas = document.getElementById("renderCanvas");
    const mod = await createExampleModule(getEnv());

    console.log("WASM module initialized:", mod);

    addWindowResizeListener(mod, 1024, 1280);
    // main() auto-runs by default in this build. If you later add -sNO_INITIAL_RUN=1,
    // uncomment the following line:
    // mod._main(0, 0);
  } catch (e) {
    console.error(e);
  }
})();
