import type { ServerWebSocket } from "bun";
import { ResourceManager } from "./resource_manager";
import type { ServerMessage, ClientMessage } from "./protocol";
import { createInitialGameState, loadResources, generateFrame } from "./game";
import type { GameState } from "./game";

interface ClientData {
  id: string;
  resourceManager: ResourceManager;
  game: GameState;
}

const PORT = 9001;
const clients = new Set<ServerWebSocket<ClientData>>();

const server = Bun.serve<ClientData>({
  port: PORT,
  fetch(req, server) {
    const url = new URL(req.url);
    
    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req, {
        data: {
          id: crypto.randomUUID(),
          resourceManager: new ResourceManager(),
          game: createInitialGameState(),
        },
      });
      
      if (upgraded) {
        return undefined;
      }
    }
    
    return new Response("WebSocket server running", { status: 200 });
  },
  
  websocket: {
    async open(ws) {
      console.log(`[WS] Client connected: ${ws.data.id}`);
      clients.add(ws);
      
      try {
        await loadResources(ws.data.game, ws.data.resourceManager);
      } catch (e) {
        console.error(`[WS] Failed to create resources:`, e);
      }
    },
    
    message(ws, message) {
      if (typeof message === "string") {
        try {
          const data = JSON.parse(message) as ClientMessage;
          
          if (data.resourceResponses) {
            for (const response of data.resourceResponses) {
              ws.data.resourceManager.handleResponse(response);
            }
          }
        } catch (e) {
          console.error("[WS] Failed to parse message:", e);
        }
      }
    },
    
    close(ws) {
      console.log(`[WS] Client disconnected: ${ws.data.id}`);
      ws.data.resourceManager.clear();
      clients.delete(ws);
    },
  },
});

console.log(`[Server] Listening on ws://localhost:${PORT}/ws`);

// Game loop - send frames at 60fps
const TARGET_FPS = 60;
const FRAME_TIME = 1000 / TARGET_FPS;
let lastFrameTime = Date.now();

setInterval(() => {
  if (clients.size === 0) {
    return;
  }
  
  const now = Date.now();
  const dt = (now - lastFrameTime) / 1000;
  lastFrameTime = now;
  
  for (const client of clients) {
    try {
      const frame = generateFrame(dt, client.data.game, clients.size);
      const pendingRequests = client.data.resourceManager.getPendingRequests();
      const message: ServerMessage = { frame };
      
      if (pendingRequests.length > 0) {
        message.resourceRequests = pendingRequests;
      }
      
      client.send(JSON.stringify(message));
    } catch (e) {
      console.error(`[WS] Failed to send to ${client.data.id}:`, e);
    }
  }
}, FRAME_TIME);
