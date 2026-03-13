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
import { createOutputLogger, ensureOutputElement } from "/examples/js/ansi_output.js";

async function loadExampleModuleFactory(maxAttempts = 120, delayMs = 500) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      // Cache-bust retries so a prior missing-module fetch does not stick.
      const mod = await import(/* @vite-ignore */`/examples/c/out/main.js?t=${Date.now()}`);
      return mod.default;
    } catch (err) {
      if (attempt === maxAttempts) {
        throw err;
      }
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }

  throw new Error("Unable to load /examples/c/out/main.js");
}

function getEnv() {
  var env = {};

  env.canvas = document.getElementById('renderCanvas');
  var output = ensureOutputElement();
  output.textContent = "";
  var outputLog = createOutputLogger(output);

  env.print = function (...args) {
    const line = args.length > 1 ? args.join(" ") : String(args[0] ?? "");
    console.log(line);
    outputLog(line);
  };

  env.printErr = function (...args) {
    const line = args.length > 1 ? args.join(" ") : String(args[0] ?? "");
    console.error(line);
    outputLog(line);
  };

  return env;
}

function applyLetterboxCanvasStyle(canvas, idealWidth, idealHeight) {
  const gameContainer = document.getElementById("gameContainer");
  const wrapper = document.getElementById("wrapper");

  // Match the desktop host model: keep a fixed internal render size and only
  // scale the DOM presentation box to a letterboxed rect.
  idealWidth = idealWidth || canvas.width || 800;
  idealHeight = idealHeight || canvas.height || 600;
  const aspectRatio = idealWidth / idealHeight;

  window.addEventListener('resize', (_event) => {
    const bounds = wrapper ? wrapper.getBoundingClientRect() : document.body.getBoundingClientRect();
    const windowWidth = Math.max(0, Math.floor(bounds.width));
    const windowHeight = Math.max(0, Math.floor(bounds.height));

    let newWidth, newHeight;
    if (windowWidth / windowHeight > aspectRatio) {
      newHeight = windowHeight;
      newWidth = windowHeight * aspectRatio;
    } else {
      newWidth = windowWidth;
      newHeight = windowWidth / aspectRatio;
    }

    if (gameContainer) {
      gameContainer.style.width = `${Math.floor(newWidth)}px`;
      gameContainer.style.height = `${Math.floor(newHeight)}px`;
    }
  });

  // force an initial resize event
  window.dispatchEvent(new Event('resize'));
}

// load the wasm module
(async function () {
  try {
    const canvas = document.getElementById("renderCanvas");
    const createExampleModule = await loadExampleModuleFactory();
    const mod = await createExampleModule(getEnv());
    const idealWidth = 1024;
    const idealHeight = 1280;

    console.log("WASM module initialized:", mod);
    console.log(`Letterbox target size: ${idealWidth}x${idealHeight}`);

    applyLetterboxCanvasStyle(canvas, idealWidth, idealHeight);
    
    // main() auto-runs by default in this build. If you later add -sNO_INITIAL_RUN=1,
    // uncomment the following line:
    // mod._main(0, 0);
  } catch (e) {
    console.error(e);
  }
})();
