import type { ServerWebSocket } from "bun";
import type { ClientMessage, ServerMessage } from "./protocol";
import type { GameClient } from "./game";
import { createGameRuntime } from "./game";
import { readFileSync } from "fs";

interface ClientData {
  id: string;
}

const DEFAULT_ENABLE_TLS = true;
const REQUESTED_PROTOCOL = process.env.RL_REMOTE_WS_PROTOCOL?.toLowerCase();
const ENABLE_TLS =
  REQUESTED_PROTOCOL === "wss"
    ? true
    : REQUESTED_PROTOCOL === "ws"
      ? false
      : DEFAULT_ENABLE_TLS;
const TLS_CERT =
  process.env.RL_REMOTE_TLS_CERT ||
  "/home/rknopf/keys/doomgiver.local/cert.pem";
const TLS_KEY =
  process.env.RL_REMOTE_TLS_KEY ||
  "/home/rknopf/keys/doomgiver.local/privkey.pem";

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
const game = createGameRuntime();

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

game.init();

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

    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req, {
        data: {
          id: crypto.randomUUID(),
        },
      });

      if (upgraded) {
        return undefined;
      }
    }

    return new Response("WebSocket server running", { status: 200 });
  },

  websocket: {
    open(ws) {
      const client = createGameClient(ws);

      console.log(`[WS] Client connected: ${client.id}`);
      clients.set(client.id, ws);
      void game.onConnect(client).catch((error) => {
        console.error(`[WS] Failed to initialize client ${client.id}:`, error);
        client.disconnect();
      });
    },

    message(ws, message) {
      if (typeof message !== "string") {
        return;
      }

      try {
        const data = JSON.parse(message) as ClientMessage;
        game.onMessage(ws.data.id, data);
      } catch (error) {
        console.error(
          `[WS] Failed to parse message from ${ws.data.id}:`,
          error,
        );
      }
    },

    close(ws) {
      console.log(`[WS] Client disconnected: ${ws.data.id}`);
      clients.delete(ws.data.id);
      game.onDisconnect(ws.data.id);
    },
  },
});

const scheme = ENABLE_TLS && TLS_CERT && TLS_KEY ? "wss" : "ws";
console.log(`[Server] Listening on ${scheme}://${HOST}:${PORT}/ws`);

const TARGET_FPS = 60;
const FRAME_TIME = 1000 / TARGET_FPS;
let lastFrameTime = Date.now();

setInterval(() => {
  const now = Date.now();
  const dt = (now - lastFrameTime) / 1000;

  lastFrameTime = now;
  game.tick(dt);
}, FRAME_TIME);

process.on("SIGINT", () => {
  game.destroy();
  server.stop(true);
  process.exit(0);
});

process.on("SIGTERM", () => {
  game.destroy();
  server.stop(true);
  process.exit(0);
});
