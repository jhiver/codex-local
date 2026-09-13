#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-1234}"
PIDS="$(pgrep -f "llama-server.*--port ${PORT}" || true)"
if [[ -z "$PIDS" ]]; then
    PIDS="$(pgrep -f "llama-server" || true)"
fi

if [[ -z "$PIDS" ]]; then
    echo "ℹ️  No running llama-server process found."
    exit 0
fi

echo "🛑 Stopping llama-server (PID: $PIDS)..."
for pid in $PIDS; do
    kill "$pid" 2>/dev/null || true
done

# Wait for process exit
for i in {1..10}; do
    if ! pgrep -f "llama-server" >/dev/null 2>&1; then
        echo "✅ llama-server stopped cleanly."
        exit 0
    fi
    sleep 0.5
done

# Force kill if still running
if pgrep -f "llama-server" >/dev/null 2>&1; then
    echo "⚠️  Process didn't stop in time. Sending SIGKILL..."
    pkill -9 -f "llama-server" || true
    echo "✅ Force terminated."
fi
