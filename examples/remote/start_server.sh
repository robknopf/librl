#!/bin/bash
cd "$(dirname "$0")/server"
PORT_VALUE="${RL_REMOTE_WS_PORT:-${PORT:-9001}}"
echo "Starting remote command buffer server..."
echo "WebSocket endpoint: ws://localhost:${PORT_VALUE}/ws"
echo ""
RL_REMOTE_WS_PORT="${PORT_VALUE}" PORT="${PORT_VALUE}" bun run dev
