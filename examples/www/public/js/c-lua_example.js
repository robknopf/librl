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
// For c->wasm build: cd examples/c-lua && make wasm (or wasm-debug)
import { createOutputLogger, ensureOutputElement } from "./ansi_output.js";

const WASM_STARTUP_TIMEOUT_MS = 15000;
const pageBase = new URL(".", window.location.href);

async function loadExampleModuleFactory(maxAttempts = 120, delayMs = 500) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      // Cache-bust retries so a prior missing-module fetch does not stick.
      const moduleUrl = new URL("examples/c-lua/out/main.js", pageBase).href;
      const mod = await import(/* @vite-ignore */`${moduleUrl}?t=${Date.now()}`);
      return mod.default;
    } catch (err) {
      if (attempt === maxAttempts) {
        throw err;
      }
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }

  throw new Error("Unable to load /examples/c-lua/out/main.js");
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

  let lastStatus = null;
  env.setStatus = function (status) {
    if (!status || status === lastStatus) {
      return;
    }
    lastStatus = status;
    outputLog(`[wasm] ${status}`);
  };

  env.onAbort = function (what) {
    const message = what ? String(what) : "WASM startup aborted";
    console.error(message);
    outputLog(`[wasm] ${message}`);
  };

  return env;
}

async function waitForModuleWithTimeout(createExampleModule, env, timeoutMs = WASM_STARTUP_TIMEOUT_MS) {
  let timeoutId = 0;

  try {
    return await Promise.race([
      createExampleModule(env),
      new Promise((_, reject) => {
        timeoutId = window.setTimeout(() => {
          reject(new Error(`Timed out after ${timeoutMs}ms while loading the wasm module`));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId) {
      window.clearTimeout(timeoutId);
    }
  }
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
    const env = getEnv();
    const mod = await waitForModuleWithTimeout(createExampleModule, env);
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
    const output = ensureOutputElement();
    const outputLog = createOutputLogger(output);
    const message = e instanceof Error ? e.message : String(e);
    outputLog(`[wasm] startup failed: ${message}`);
  }
})();
