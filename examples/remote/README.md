# Remote Thin Client Example

Server-driven rendering over WebSocket. Game logic runs on a Bun/TypeScript server, which streams frame command buffers to a thin C/librl client that handles rendering, audio, and resource management.

## Architecture

```
┌─────────────────────────────┐    WebSocket (JSON)    ┌─────────────────────────────┐
│  Server (Bun + TypeScript)  │◄──────────────────────►│  Thin Client (C + librl)    │
│                             │                        │                             │
│  game.ts    - scene logic   │  Frame commands ──────►│  rl_json_parser - decode     │
│  server.ts  - WS service    │  Resource requests ───►│  rl_resource_handler - load  │
│  resource_manager.ts        │◄── Resource responses  │  rl_ws_client - transport    │
│  resource_protocol.ts       │                        │  main.c - render loop        │
└─────────────────────────────┘                        └─────────────────────────────┘
```

## How It Works

1. Client connects to the server via WebSocket
2. Server requests resources (colors, fonts, textures, models, cameras, sprite3ds)
3. Client loads assets asynchronously and responds with resource handles
4. Server sends frame command buffers at 60fps using those handles
5. Client executes 3D/2D/audio commands each frame

### Resource Protocol

Resources are created via a request/response protocol:
- Server sends `resourceRequests` packets with a unique RID and type
- Client creates the resource (async for file-based assets) and responds with a handle
- Server's `ResourceManager` resolves promises when handles arrive
- Handles are then used in frame commands (e.g. `color: 42` in a DRAW_CUBE)

### Packet Types

WebSocket traffic is split by intent instead of compacting frame + resource data
into the same packet:
- `frame` packets carry only render/audio commands for the next frame
- `resourceRequests` packets carry only resource creation requests
- `resourceResponses` packets carry only client-side handle responses

This keeps frame delivery disposable while resource traffic stays queueable.

### Async Loading

File-based resources (fonts, textures, models, sounds, music, sprite3ds) use async loading on the client:
- `rl_loader_import_asset_async()` starts the fetch
- `rl_loader_poll_task()` checks each frame
- `rl_loader_finish_task()` + resource create on completion
- Response sent back to server with the new handle

## File Structure

### Server (`server/src/`)
| File | Purpose |
|------|---------|
| `server.ts` | WebSocket service, connection management, frame loop |
| `game.ts` | Scene logic, resource loading, frame generation |
| `resource_manager.ts` | Tracks resource requests/responses with promises |
| `resource_protocol.ts` | Resource request/response type definitions |
| `protocol.ts` | Typed packet definitions for frame/resource traffic |
| `types.ts` | Command type enum and command interfaces |

### Client
| File | Purpose |
|------|---------|
| `main.c` | Init, render loop, local overlay (bandwidth stats) |
| `rl_ws_client.h/c` | WebSocket transport, reconnection, bandwidth tracking |
| `rl_json_parser.h/c` | JSON → `rl_frame_command_buffer_t` deserialization |
| `rl_resource_handler.h/c` | Processes resource requests, async loading |
| `rl_resource_protocol.h` | C resource request/response structs and enums |
| `rl_resource_registry.h/c` | Handle storage for created resources |

## Build & Run

### 1. Start the server
```bash
./start_server.sh
# or manually:
cd server && bun run --watch src/server.ts
```
Server listens on `ws://localhost:9001/ws`. Uses `--watch` for auto-reload on TS changes.

### 2. Build the client

**WASM** (for browser):
```bash
make wasm
# Then serve via examples/www
```

**Desktop**:
```bash
make desktop
./out/main
```

### 3. Open in browser
Navigate to the remote example page. The client connects, loads resources, and renders the server-driven scene.

## Command Types

| Type | Name | Rendering Pass |
|------|------|---------------|
| 0 | CLEAR | Clear |
| 1 | DRAW_TEXT | 2D |
| 2 | DRAW_SPRITE3D | 3D |
| 3 | PLAY_SOUND | Audio |
| 4 | DRAW_MODEL | 3D |
| 5 | DRAW_TEXTURE | 2D |
| 6 | DRAW_CUBE | 3D |
| 7 | DRAW_GROUND_TEXTURE | 3D |

## Resource Request Types

| Type | Name | Loading |
|------|------|---------|
| 0 | CREATE_COLOR | Sync |
| 1 | CREATE_FONT | Async |
| 2 | CREATE_TEXTURE | Async |
| 3 | CREATE_MODEL | Async |
| 4 | CREATE_SOUND | Async |
| 5 | CREATE_MUSIC | Async |
| 6 | CREATE_CAMERA3D | Sync |
| 7 | CREATE_SPRITE3D | Async |
| 99 | DESTROY | Sync (not yet implemented) |

## Client Overlay

The client draws a local bandwidth stats overlay (top-right) using a locally-loaded font, independent of the server. This shows `in: X.X kb/s  out: X.X kb/s` computed from actual WebSocket traffic.

## Current Demo Scene

The server recreates the `lua_demo.lua` scene in TypeScript (`game.ts`):
- Bobbing WG logo sprite3d with distance-scaled blob shadow
- Orbiting animated Gumshoe model
- Rotating logo texture in the corner
- Animated text with wobble effect
- Camera at (12, 12, 12) looking at origin

## Future Improvements

- [ ] Switch to binary format (MessagePack or custom)
- [ ] Add input forwarding (client → server)
- [ ] Add compression for command buffers
- [ ] Desktop WebSocket library (mongoose) for standalone client
- [ ] In-process mode (bypass WebSocket for local development)
- [ ] Delta encoding for command buffers
- [ ] Resource destruction / lifecycle management
