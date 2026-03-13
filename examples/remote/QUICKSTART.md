# Remote Command Buffer - Quick Start

## Quick Test (WASM)

### Terminal 1: Start Server
```bash
cd examples/remote
./start_server.sh
```

### Terminal 2: Build & Serve Client
```bash
cd examples/remote
make wasm

cd ../www
npm run dev
```

### Browser
Navigate to the remote example page. You should see:
- Bobbing WG logo with shadow
- Orbiting animated Gumshoe character
- Rotating logo texture (top area)
- Animated text overlay
- Bandwidth stats (top-right)

## Quick Test (Desktop)

```bash
# Terminal 1
./start_server.sh

# Terminal 2
make desktop
./out/main
```

## Development Workflow

1. **Edit scene logic** in `server/src/game.ts`
2. **Hot reload** happens automatically (`bun --watch`)
3. Client receives new commands immediately
4. **No client rebuild needed** for game logic changes

Only rebuild the WASM client when changing C code (main.c, ws_client, resource handler, etc.):
```bash
make wasm
# Then refresh browser
```

## Troubleshooting

### Server won't start
- Ensure Bun is installed: `bun --version`
- Check port 9001 is available: `lsof -i :9001`

### Client won't connect
- Verify server is running: `curl http://localhost:9001`
- Check browser console for WebSocket errors
- Ensure URL matches: `ws://localhost:9001/ws`

### Resources not loading
- Check server logs for `[Game] ... ready` messages
- Check browser console for asset fetch failures
- Verify assets exist under `examples/www/public/assets/`

### No rendering
- Resources must finish loading before commands reference them
- Server sends empty frames until `resourcesReady` is true
- Check that `has_frame` and `commands.count > 0` in client
