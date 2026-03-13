#!/bin/bash
cd "$(dirname "$0")/server"
echo "Starting remote command buffer server..."
echo "WebSocket endpoint: ws://localhost:9001/ws"
echo ""
bun run dev
