import { createOutputLogger, ensureOutputElement } from "./ansi_output.js";

const WASM_STARTUP_TIMEOUT_MS = 15000;
const pageBase = new URL(".", window.location.href);
const moduleUrl = new URL("examples/nim/out/wasm/main.js", pageBase).href;
const moduleDir = new URL("./", moduleUrl);

async function loadModuleFactory(maxAttempts = 120, delayMs = 500) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const mod = await import(/* @vite-ignore */ `${moduleUrl}?t=${Date.now()}`);
      return mod.default;
    } catch (err) {
      if (attempt === maxAttempts) throw err;
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error("Unable to load Nim WASM module");
}

function getEnv() {
  const env = {};
  env.canvas = document.getElementById("renderCanvas");

  const output = ensureOutputElement();
  output.textContent = "";
  const outputLog = createOutputLogger(output);

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
    if (!status || status === lastStatus) return;
    lastStatus = status;
    outputLog(`[wasm] ${status}`);
  };

  env.onAbort = function (what) {
    const message = what ? String(what) : "WASM startup aborted";
    console.error(message);
    outputLog(`[wasm] ${message}`);
  };

  env.locateFile = function (path) {
    return new URL(path, moduleDir).href;
  };

  return env;
}

async function waitForModuleWithTimeout(factory, env, timeoutMs = WASM_STARTUP_TIMEOUT_MS) {
  let timeoutId = 0;
  try {
    return await Promise.race([
      factory(env),
      new Promise((_, reject) => {
        timeoutId = window.setTimeout(() => {
          reject(new Error(`Timed out after ${timeoutMs}ms while loading the wasm module`));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId) window.clearTimeout(timeoutId);
  }
}

function applyLetterboxCanvasStyle(canvas, idealWidth, idealHeight) {
  const gameContainer = document.getElementById("gameContainer");
  const wrapper = document.getElementById("wrapper");
  idealWidth = idealWidth || canvas.width || 800;
  idealHeight = idealHeight || canvas.height || 600;
  const aspectRatio = idealWidth / idealHeight;

  window.addEventListener("resize", () => {
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
  window.dispatchEvent(new Event("resize"));
}

(async function () {
  try {
    const canvas = document.getElementById("renderCanvas");
    const factory = await loadModuleFactory();
    const env = getEnv();
    const mod = await waitForModuleWithTimeout(factory, env);

    console.log("Nim WASM module initialized:", mod);
    applyLetterboxCanvasStyle(canvas, 800, 600);
  } catch (e) {
    console.error(e);
    const output = ensureOutputElement();
    const outputLog = createOutputLogger(output);
    const message = e instanceof Error ? e.message : String(e);
    outputLog(`[wasm] startup failed: ${message}`);
  }
})();
