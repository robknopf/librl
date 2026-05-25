import type { ServerWebSocket } from "bun";
import { existsSync, readFileSync, statSync } from "fs";
import { loadServerConfig } from "./config";
import {
  startPerClientWatcher,
  type WatchEntry,
} from "./filewatcher";
import { serveStaticRequest } from "./static";

interface ClientData {
  id: string;
  stopWatcher?: () => void;
}

interface ServerMessage {
  type: string;
  data: any;
}

interface ClientMessage {
  type: string;
  data: any;
}

const config = loadServerConfig();
const {
  enableTls: ENABLE_TLS,
  tlsCert: TLS_CERT,
  tlsKey: TLS_KEY,
  host: HOST,
  port: PORT,
  publicRoot,
  siteRoot,
  watchDebounceMs,
  httpMounts,
} = config;

const clients = new Map<string, ServerWebSocket<ClientData>>();

function messageTypeForExt(_ext: string): string {
  return "file_changed";
}

function notifyClient(
  ws: ServerWebSocket<ClientData>,
  assetPath: string,
  ext: string,
): void {
  const type = messageTypeForExt(ext);
  const message: ServerMessage = { type, data: { path: assetPath, ext } };
  ws.send(JSON.stringify(message));
  console.log(`[watch] ${type} → ${ws.data.id}: ${assetPath}`);
}

if (!existsSync(publicRoot) || !statSync(publicRoot).isDirectory()) {
  throw new Error(`[ERROR] Watcher public root is not a directory: ${publicRoot}`);
}

if (!existsSync(siteRoot) || !statSync(siteRoot).isDirectory()) {
  throw new Error(`[ERROR] HTTP site root is not a directory: ${siteRoot}`);
}
for (const mount of httpMounts) {
  if (!existsSync(mount.root) || !statSync(mount.root).isDirectory()) {
    throw new Error(
      `[ERROR] HTTP mount root is not a directory: ${mount.prefix} → ${mount.root}`,
    );
  }
}

console.log(`Watcher public root directory: ${publicRoot}`);
console.log(`HTTP site root directory: ${siteRoot}`);
if (httpMounts.length > 0) {
  console.log(
    "HTTP mounts:",
    httpMounts.map((mount) => `${mount.prefix} → ${mount.root}`).join(", "),
  );
}

const server = Bun.serve<ClientData>({
  hostname: HOST,
  port: PORT,
  ...(ENABLE_TLS && TLS_CERT && TLS_KEY
    ? {
        tls: {
          cert: readFileSync(TLS_CERT),
          key: readFileSync(TLS_KEY),
        },
      }
    : {}),
  fetch(req, server) {
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/$/, "") || "/";

    if (path === "/ws") {
      const wantsWs =
        (req.headers.get("upgrade") || "").toLowerCase() === "websocket";
      if (!wantsWs) {
        console.warn(
          `[WS] ${req.method} /ws without Upgrade: websocket (got upgrade=${JSON.stringify(req.headers.get("upgrade"))})`,
        );
        return new Response("Expected WebSocket Upgrade request", {
          status: 426,
          headers: { Connection: "Upgrade", Upgrade: "websocket" },
        });
      }

      const upgraded = server.upgrade(req, {
        data: {
          id: crypto.randomUUID(),
        },
      });

      if (upgraded) {
        return;
      }

      console.error(
        "[WS] server.upgrade(req) returned false — Bun rejected this handshake (see Bun docs / Client connected never runs)",
      );
      return new Response("WebSocket upgrade failed", { status: 400 });
    }

    return serveStaticRequest(req, url, {
      publicRoot,
      siteRoot,
      mounts: httpMounts,
    });
  },

  websocket: {
    open(ws) {
      console.log(`[WS] Client connected: ${ws.data.id}`);
      clients.set(ws.data.id, ws);
    },

    message(ws, message) {
      console.log("got message:", message);
      if (typeof message !== "string") return;
      try {
        const msg = JSON.parse(message) as ClientMessage;
        if (msg.type === "watch") {
          const entries = msg.data?.watch as WatchEntry[] | undefined;
          if (!Array.isArray(entries) || entries.length === 0) {
            console.warn(`[WS] ${ws.data.id}: watch message missing entries`);
            return;
          }
          if (ws.data.stopWatcher) {
            ws.data.stopWatcher();
          }
          ws.data.stopWatcher = startPerClientWatcher({
            publicRoot,
            entries,
            debounceMs: watchDebounceMs,
            onFileChanged: (assetPath, ext) => notifyClient(ws, assetPath, ext),
          });
        }
      } catch (error) {
        console.error(`[WS] Failed to parse message from ${ws.data.id}:`, error);
      }
    },

    close(ws) {
      console.log(`[WS] Client disconnected: ${ws.data.id}`);
      if (ws.data.stopWatcher) {
        ws.data.stopWatcher();
      }
      clients.delete(ws.data.id);
    },
  },
});

const httpScheme = ENABLE_TLS && TLS_CERT && TLS_KEY ? "https" : "http";
const wsScheme = ENABLE_TLS && TLS_CERT && TLS_KEY ? "wss" : "ws";
console.log(`[Server] WebSocket on ${wsScheme}://${HOST}:${PORT}/ws`);
console.log(`[Server] HTTP static on ${httpScheme}://${HOST}:${PORT}/`);

process.on("SIGINT", () => {
  for (const ws of clients.values()) ws.data.stopWatcher?.();
  server.stop(true);
  process.exit(0);
});

process.on("SIGTERM", () => {
  for (const ws of clients.values()) ws.data.stopWatcher?.();
  server.stop(true);
  process.exit(0);
});
