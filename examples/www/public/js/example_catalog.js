function buildRemoteEnv({ moduleDir, createDefaultEnv }) {
  const env = createDefaultEnv(moduleDir);
  const params = new URLSearchParams(window.location.search);
  const protocolFromQuery = params.get("protocol");
  const hostFromQuery = params.get("host");
  const portFromQuery = params.get("port");
  const assetHostFromQuery = params.get("asset_host");
  const wsProtocol = window.location.protocol === "https:" ? "wss" : "ws";
  const defaultHost = window.location.hostname || "localhost";
  const defaultPort = "9001";
  const defaultAssetHost = new URL(".", window.location.href).href.replace(/\/$/, "");

  env.env = {
    RL_REMOTE_WS_PROTOCOL:
      protocolFromQuery && protocolFromQuery.length > 0 ? protocolFromQuery : wsProtocol,
    RL_REMOTE_WS_HOST:
      hostFromQuery && hostFromQuery.length > 0 ? hostFromQuery : defaultHost,
    RL_REMOTE_WS_PORT: portFromQuery && portFromQuery.length > 0 ? portFromQuery : defaultPort,
    RL_ASSET_HOST:
      assetHostFromQuery && assetHostFromQuery.length > 0
        ? assetHostFromQuery
        : defaultAssetHost,
  };

  return env;
}

/** Web testbed examples — `?example=<key>` selects one row. */
export const EXAMPLES = {
  remote: {
    label: "Remote",
    module: "examples/remote/out/main.js",
    buildEnv: buildRemoteEnv,
  },
  js: {
    label: "Pure JS",
    module: "examples/js/js_example.js",
    standalone: true,
  },
  "c-lua": {
    label: "C-Lua",
    module: "examples/c-lua/out/main.js",
  },
  "c-simple": {
    label: "C-simple",
    module: "examples/c-simple/out/main.js",
  },
  "nim-wasm-simple": {
    label: "Nim Simple (wasm)",
    module: "examples/nim-simple/out/wasm/main.js",
  },
  "nim-js-simple": {
    label: "Nim Simple (js)",
    module: "assets/scripts/nim/main.js",
    reloadable: true,
  },
  "haxe-wasm-simple": {
    label: "Haxe Simple (wasm)",
    module: "examples/haxe-simple/out/wasm/Main.js",
  },
  "haxe-js-simple": {
    label: "Haxe Simple (js)",
    module: "assets/scripts/haxe/main.js",
    reloadable: true,
  },
  cppia: {
    label: "Cppia",
    module: "examples/cppia/out/wasm/ScriptableMain.js",
  },
};

/** @param {string} key */
export function getExample(key) {
  return EXAMPLES[key] ?? null;
}

export function exampleKeys() {
  return Object.keys(EXAMPLES);
}
