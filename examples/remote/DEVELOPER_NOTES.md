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
    rl_render_begin()
    execute_clear()             — type 0 commands
    rl_render_begin_mode_3d()
    execute_3d()                — types 2,4,6,7
    rl_render_end_mode_3d()
    execute_2d()                — types 1,5
    draw bandwidth overlay      — local font, not server command
    rl_render_end()
```

## Server Structure

- **`server.ts`** — Pure WebSocket service. Manages connections, routes messages, runs the frame loop. No game logic.
- **`game.ts`** — Scene logic. Exports `GameState`, `createInitialGameState()`, `loadResources()`, `generateFrame()`. Doesn't know about WebSockets.
- **`resource_manager.ts`** — Promise-based resource request tracking. Helpers: `createColor`, `createFont`, `createTexture`, `createModel`, `createSound`, `createMusic`, `createCamera3D`, `createSprite3D`.
- **`resource_protocol.ts`** — TypeScript interfaces for request/response types.
- **`types.ts`** — Command type enum and command interfaces.
- **`protocol.ts`** — Typed packet definitions (`frame`, `resourceRequests`, `resourceResponses`).

## Why Remote Exists

- The remote path exists because HCR/Asyncify/browser-hosted scripting was clearly heading toward a large maintenance problem.
- The "clean" answer for local scripting would have been a fully-declared manifest/bootstrap model, but in practice the module had become the game, not a thin scripting host.
- Remote forces the boundary to be explicit:
  - what is frame state
  - what is persistent resource state
  - what needs request/response behavior
  - what belongs to transport vs runtime vs game objects
- That pressure is useful. It flushes out the actual `librl` runtime/API shape instead of letting local VM conveniences hide design problems.

## Possible Module Direction

- `remote` may eventually become a real module type, similar in spirit to the old `lua` module.
- The difference is backend, not architecture:
  - `lua` hosted gameplay in a local VM
  - `remote` would host gameplay over a transport such as WebSocket
- If that happens, the game/runtime-facing API should feel the same whether it is:
  - local and in-process
  - remote and transport-backed
- That means current remote server code should be treated as a runtime experiment, not just an example app.

## Boundary Notes

- Build server-side gameplay code as if it may later collapse into a direct/in-process runtime.
- `server.ts` should stay transport-only:
  - websocket
  - encode/decode
  - connection lifecycle
- `game.ts` or later runtime/module code should own:
  - init/destroy
  - tick
  - connect/disconnect policy
  - object/resource lifecycle
  - request/response semantics
- Avoid baking game-specific concepts into transport/protocol layers.
- Prefer generic request/response and evented broker patterns over per-feature ad hoc RID handling.
- Object wrappers like `Model` should own:
  - load
  - transform/state
  - draw emission
  - pick request
  - destroy

## Proxy Naming Note

- Some current server-side helpers are effectively transport/runtime-backed stand-ins for future direct `rl_*` calls.
- It may be useful to think of these as **proxies**:
  - they look object-like or API-like
  - today they serialize over the remote connection
  - later they may call real `rl_*` functions directly
- This is a useful mental model when designing APIs:
  - keep the surface clean and runtime-facing
  - do not let transport details leak upward
  - assume a future backend may bypass WebSocket entirely

## Adding a New Resource Type

### Taxonomy: Choose the Right Pattern

| Pattern | Examples | When to Use |
|---------|----------|-------------|
| **Value handle (lightweight, pooled)** | `rl_color` | Cheap to create, no GPU resources, equality-by-value semantics |
| **Shared cached asset (refcounted)** | `rl_texture`, `rl_font` | Expensive GPU upload, path-based deduplication, multiple consumers |
| **Instanced renderable (handle pool)** | `rl_model`, `rl_sprite3d`, `rl_sprite2d` | Per-instance transform/state, created/destroyed frequently, owns no GPU data directly |
| **Stream handle (lifecycle managed)** | `rl_music`, `rl_sound` | Runtime decode state, owns its own data, one-shot or streaming |

### Implementation Checklist

**C runtime:**
1. Add public header `include/rl_<name>.h` with create/destroy/draw API
2. Add internal header `src/internal/rl_<name>.h` with init/deinit decls
3. Implement in `src/rl_<name>.c` following chosen pattern above
4. Wire init/deinit into `rl_init()`/`rl_deinit()` in `src/rl.c`
5. Add exports to `Makefile` KEEP list

**If handle pool pattern:**
- Use `rl_handle_pool_t` for sparse handle allocation
- Store per-instance state (transform, etc.) in instance array indexed by handle
- Implement `set_transform()` + `draw()` split (transform stored, draw uses stored values)

**If frame commands needed (Lua/remote contexts):**
1. Add command type to `rl_render_command_type_t` in `include/rl_frame_command.h`
2. Add command struct to `rl_frame_command_data_t` union
3. Add executor case in `src/rl_frame_command.c` (in appropriate 2D/3D/clear handler)

**Lua module:**
1. Add bindings in `modules/lua/src/rl_module_lua.c`
2. Create Lua wrapper in `examples/www/public/assets/scripts/lua/<name>.lua`
3. Follow pattern: `load()` caches handle, `set_transform()` tracks dirty state, `draw()` emits command

**Remote server:**
1. Add enum to `ResourceRequestType` in `resource_protocol.ts`
2. Add request interface to `AnyResourceRequest` union
3. Add handler in `rl_resource_handler.c` (sync or async)
4. Add helper in `resource_manager.ts`

**Bindings:**
- Nim (`bindings/nim/rl.nim`): Direct API imports only, no frame command structs
- Haxe (`bindings/haxe/rl/RL.hx`): Direct API imports only
- JS (`bindings/js/rl.js`): Direct API where applicable

**Documentation:**
- Add section to `docs/API.md`
- Update `README.md` Lua module list if adding wrapper

## Adding a New Command Type

1. Add to `CommandType` enum in `types.ts`
2. Add command interface in `types.ts`
3. Add to `Command` union type in `types.ts`
4. Add JSON parsing in `rl_json_parser.c`
5. Add execution in `rl_frame_command.c` (in the appropriate 2D/3D/clear handler)

## Bandwidth Stats

Client-side only. `rl_ws_client_t` accumulates `bytes_in` / `bytes_out` and computes per-second rates every 1 second in `rl_ws_client_tick()`. Retrieved via `rl_ws_client_get_bandwidth_stats()` and drawn as a local overlay with a client-loaded font.

## Known Limitations

- Resource destruction (`DESTROY = 99`) is not yet implemented
- No input forwarding from client to server
- JSON protocol — binary (MessagePack) would reduce bandwidth significantly
- Camera is set active on creation; no command to change it per-frame
- Desktop websocket callbacks are normalized through `websocket_poll()` so
  higher layers can treat wasm and desktop the same way
