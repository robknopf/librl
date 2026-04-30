import { createOutputLogger, ensureOutputElement } from "./ansi_output.js";

const STARTUP_TIMEOUT_MS = 15000;
const IDEAL_WIDTH = 1024;
const IDEAL_HEIGHT = 1280;

function getPageBase() {
  return new URL(".", window.location.href);
}

function createOutputLog() {
  const output = ensureOutputElement();
  output.textContent = "";
  return createOutputLogger(output);
}

async function loadModuleFactory(moduleUrl, maxAttempts = 120, delayMs = 500) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const mod = await import(/* @vite-ignore */ `${moduleUrl}?t=${Date.now()}`);
      return mod.default;
    } catch (err) {
      if (attempt === maxAttempts) throw err;
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error(`Unable to load module: ${moduleUrl}`);
}

function createDefaultEnv(moduleDir) {
  const env = {};
  env.canvas = document.getElementById("renderCanvas");

  const outputLog = createOutputLog();

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
    const message = what ? String(what) : "startup aborted";
    console.error(message);
    outputLog(`[wasm] ${message}`);
  };

  env.locateFile = function (path) {
    return new URL(path, moduleDir).href;
  };

  return env;
}

async function waitForModuleWithTimeout(factory, env, timeoutMs = STARTUP_TIMEOUT_MS) {
  let timeoutId = 0;
  try {
    return await Promise.race([
      factory(env),
      new Promise((_, reject) => {
        timeoutId = window.setTimeout(() => {
          reject(new Error(`Timed out after ${timeoutMs}ms while loading the module`));
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
  const width = idealWidth || canvas.width || 800;
  const height = idealHeight || canvas.height || 600;
  const aspectRatio = width / height;

  window.addEventListener("resize", () => {
    const bounds = wrapper ? wrapper.getBoundingClientRect() : document.body.getBoundingClientRect();
    const windowWidth = Math.max(0, Math.floor(bounds.width));
    const windowHeight = Math.max(0, Math.floor(bounds.height));
    let newWidth;
    let newHeight;

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

export async function runExample(displayName, modulePath, options = {}) {
  const { buildEnv, onModuleReady } = options;
  const pageBase = getPageBase();
  const moduleUrl = new URL(modulePath, pageBase).href;
  const moduleDir = new URL("./", moduleUrl);
  let cleanup = null;

  try {
    const canvas = document.getElementById("renderCanvas");
    const factory = await loadModuleFactory(moduleUrl);
    const env = buildEnv ? buildEnv({ moduleDir, createDefaultEnv }) : createDefaultEnv(moduleDir);
    const mod = await waitForModuleWithTimeout(factory, env);

    console.log(`${displayName} module initialized:`, mod);
    if (onModuleReady) {
      cleanup = await onModuleReady(mod);
    }
    applyLetterboxCanvasStyle(canvas, IDEAL_WIDTH, IDEAL_HEIGHT);
  } catch (e) {
    console.error(e);
    if (typeof cleanup === "function") {
      cleanup();
    }
    const outputLog = createOutputLog();
    const message = e instanceof Error ? e.message : String(e);
    outputLog(`[wasm] startup failed: ${message}`);
  }
}
