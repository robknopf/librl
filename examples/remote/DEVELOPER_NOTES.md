# Developer Notes

## Resource Flow

```
Server                                         Client
  │                                              │
  │──────── WebSocket Connect ──────────────────►│
  │                                              │
  │  loadResources() starts:                     │
  │  createColor(221,87,54,255)                  │
  │    → queues {rid:1, type:0, r,g,b,a}        │
  │                                              │
  │  Frame loop sends request packet:            │
  │  { type:"resourceRequests",                  │
  │    resourceRequests: [{rid:1, ...}] }───────►│
  │                                              │
  │  Frame loop sends frame packet:              │
  │  { type:"frame", frame: {...} }─────────────►│
  │                                              │
  │                               rl_color_create() → handle 42
  │                                              │
  │  { type:"resourceResponses",                 │
  │    [{rid:1, handle:42, success:true}] }◄─────│
  │                                              │
  │  Promise resolves → accentColor = 42         │
  │  Next request queued (font, texture, etc.)   │
  │                                              │
  │  ... async assets load over multiple frames  │
  │                                              │
  │  resourcesReady = true                       │
  │  Commands now reference real handles:        │
  │  { type: DRAW_TEXT, color: 42, ... }────────►│
```

## Resource Request Lifecycle

1. **Server** calls `rm.createTexture("assets/foo.png")` — returns a Promise
2. **ResourceManager** assigns a RID, stores promise, queues request
3. **Frame loop** picks up pending requests via `getPendingRequests()` (each sent only once)
4. **Client** receives request in a resource-request packet, starts async load
5. **Client** polls `rl_loader_poll_task()` each frame until asset is fetched
6. **Client** calls `rl_loader_finish_task()` then creates the resource handle
7. **Client** sends response with `{rid, handle, success}`
8. **Server** matches RID, resolves promise, game code continues

## Sync vs Async Resources

**Sync** (immediate response in same frame):
- Colors — `rl_color_create()` is instant
- Camera3D — `rl_camera3d_create()` + `rl_camera3d_set_active()` is instant

**Async** (response comes in a later frame, after file fetch):
- Font, Texture, Model, Sound, Music, Sprite3D
- Uses `rl_loader_import_asset_async()` → poll → finish → create handle

## Client Rendering Pipeline

Each frame, `main.c` runs:
```
on_tick():
  poll overlay font loader (local, not server-driven)
  rl_ws_client_tick()           — bandwidth stats, reconnect
  rl_ws_client_poll()           — process incoming messages
  get_pending_responses()       — sync resource responses
  send_responses()              — send them back
  poll_resource_loads()         — check async loads
  send_responses()              — send completed async ones

  if has_frame:
    rl_frame_begin()
    execute_clear()             — type 0 commands
    rl_begin_mode_3d()
    execute_3d()                — types 2,4,6,7
    rl_end_mode_3d()
    execute_2d()                — types 1,5
    draw bandwidth overlay      — local font, not server command
    rl_frame_end()
```

## Server Structure

- **`server.ts`** — Pure WebSocket service. Manages connections, routes messages, runs the frame loop. No game logic.
- **`game.ts`** — Scene logic. Exports `GameState`, `createInitialGameState()`, `loadResources()`, `generateFrame()`. Doesn't know about WebSockets.
- **`resource_manager.ts`** — Promise-based resource request tracking. Helpers: `createColor`, `createFont`, `createTexture`, `createModel`, `createSound`, `createMusic`, `createCamera3D`, `createSprite3D`.
- **`resource_protocol.ts`** — TypeScript interfaces for request/response types.
- **`types.ts`** — Command type enum and command interfaces.
- **`protocol.ts`** — Typed packet definitions (`frame`, `resourceRequests`, `resourceResponses`).

## Adding a New Resource Type

1. Add enum value to `rl_resource_request_type_t` in `rl_resource_protocol.h`
2. Add data struct to the request union in `rl_resource_protocol.h`
3. Add handler in `rl_resource_handler.c` (sync or async path)
4. Add to `ResourceRequestType` enum in `resource_protocol.ts`
5. Add TypeScript interface in `resource_protocol.ts`
6. Add to `AnyResourceRequest` union in `resource_protocol.ts`
7. Add helper method in `resource_manager.ts`

## Adding a New Command Type

1. Add to `CommandType` enum in `types.ts`
2. Add command interface in `types.ts`
3. Add to `Command` union type in `types.ts`
4. Add JSON parsing in `rl_json_parser.c`
5. Add execution in `rl_frame_commands.c` (in the appropriate 2D/3D/clear handler)

## Bandwidth Stats

Client-side only. `rl_ws_client_t` accumulates `bytes_in` / `bytes_out` and computes per-second rates every 1 second in `rl_ws_client_tick()`. Retrieved via `rl_ws_client_get_bandwidth_stats()` and drawn as a local overlay with a client-loaded font.

## Known Limitations

- Resource destruction (`DESTROY = 99`) is not yet implemented
- No input forwarding from client to server
- JSON protocol — binary (MessagePack) would reduce bandwidth significantly
- Camera is set active on creation; no command to change it per-frame
- Desktop websocket callbacks are normalized through `websocket_poll()` so
  higher layers can treat wasm and desktop the same way
