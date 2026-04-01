import { runExample } from "./example_runner.js";

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
    RL_REMOTE_WS_PROTOCOL: protocolFromQuery && protocolFromQuery.length > 0 ? protocolFromQuery : wsProtocol,
    RL_REMOTE_WS_HOST: hostFromQuery && hostFromQuery.length > 0 ? hostFromQuery : defaultHost,
    RL_REMOTE_WS_PORT: portFromQuery && portFromQuery.length > 0 ? portFromQuery : defaultPort,
    RL_ASSET_HOST: assetHostFromQuery && assetHostFromQuery.length > 0 ? assetHostFromQuery : defaultAssetHost,
  };

  return env;
}

runExample("Remote", "examples/remote/out/main.js", { buildEnv: buildRemoteEnv });
