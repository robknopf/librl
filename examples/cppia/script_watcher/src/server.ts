import type { ServerWebSocket } from "bun";
import { readFileSync } from "fs";
import * as path from "path";
import {
  defaultPublicRoot,
  startPerClientWatcher,
  type WatchEntry,
} from "./filewatcher";
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

interface GameClient {
  id: string;
  send: (message: ServerMessage) => void;
  disconnect: () => void;
}

const DEFAULT_ENABLE_TLS = false;
const REQUESTED_PROTOCOL = process.env.RL_REMOTE_WS_PROTOCOL?.toLowerCase();
const ENABLE_TLS =
  REQUESTED_PROTOCOL === "wss"
    ? true
    : REQUESTED_PROTOCOL === "ws"
      ? false
      : DEFAULT_ENABLE_TLS;

// TODO: get keys directory from the .env file
const keysDir = Bun.env.KEYS_DIR || "";
const TLS_CERT = path.join(keysDir, "cert.pem");
const TLS_KEY = path.join(keysDir, "privkey.pem");


const DEFAULT_PORT = 9001;
const PORT = (() => {
  const raw = process.env.RL_REMOTE_WS_PORT || process.env.PORT;
  const parsed = raw ? Number.parseInt(raw, 10) : NaN;
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed;
  }
  return DEFAULT_PORT;
})();

const DEFAULT_HOST = "0.0.0.0";
const HOST = process.env.RL_REMOTE_WS_HOST || DEFAULT_HOST;


const clients = new Map<string, ServerWebSocket<ClientData>>();

function sendMessage(
  ws: ServerWebSocket<ClientData>,
  message: ServerMessage,
): void {
  ws.send(JSON.stringify(message));
}

function disconnectClient(ws: ServerWebSocket<ClientData>): void {
  ws.close();
}

function createGameClient(ws: ServerWebSocket<ClientData>): GameClient {
  return {
    id: ws.data.id,
    send: (message) => sendMessage(ws, message),
    disconnect: () => disconnectClient(ws),
  };
}

// Map a file extension to a websocket message type. Keep `cppia_reload` for
// back-compat with existing clients; everything else uses a generic
// `file_changed` message containing the extension.
function messageTypeForExt(ext: string): string {
  switch (ext) {
    case ".cppia":
      return "cppia_reload";
    default:
      return "file_changed";
  }
}

function notifyClient(ws: ServerWebSocket<ClientData>, assetPath: string, ext: string): void {
  const type = messageTypeForExt(ext);
  const message: ServerMessage = { type, data: { path: assetPath, ext } };
  ws.send(JSON.stringify(message));
  console.log(`[watch] ${type} → ${ws.data.id}: ${assetPath}`);
}

const publicRoot = Bun.env.RL_REMOTE_PUBLIC_ROOT ?? defaultPublicRoot();
const watchDebounceMs = (() => {
  const v = Number.parseInt(Bun.env.RL_REMOTE_WATCH_DEBOUNCE_MS ?? "150", 10);
  return Number.isFinite(v) ? v : 150;
})();

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

    return new Response("WebSocket server running", { status: 200 });
  },

  websocket: {
    open(ws) {
      console.log(`[WS] Client connected: ${ws.data.id}`);
      clients.set(ws.data.id, ws);
    },

    message(ws, message) {
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

const scheme = ENABLE_TLS && TLS_CERT && TLS_KEY ? "wss" : "ws";
console.log(`[Server] Listening on ${scheme}://${HOST}:${PORT}/ws`);

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
