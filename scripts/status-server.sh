#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-1234}"
URL="http://${HOST}:${PORT}/v1/models"

PID="$(pgrep -f "llama-server.*--port ${PORT}" || true)"

if [[ -z "$PID" ]]; then
    # Fallback search for any llama-server
    PID="$(pgrep -f "llama-server" || true)"
fi

if curl -s -m 2 "$URL" >/dev/null 2>&1; then
    MODEL_INFO="$(curl -s -m 2 "$URL")"
    MODEL_ID="$(echo "$MODEL_INFO" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4 || echo "unknown")"
    N_CTX="$(echo "$MODEL_INFO" | grep -o '"n_ctx":[0-9]*' | head -n 1 | cut -d':' -f2 || echo "unknown")"
    
    echo "✅ llama-server is ACTIVE and HEALTHY"
    echo "   PID:      ${PID:-running}"
    echo "   Endpoint: http://${HOST}:${PORT}/v1"
    echo "   Model:    ${MODEL_ID}"
    echo "   Context:  ${N_CTX} tokens"
    exit 0
else
    echo "❌ llama-server is OFFLINE (no response on http://${HOST}:${PORT})"
    if [[ -n "$PID" ]]; then
        echo "   ⚠️  A llama-server process (PID: $PID) was found but is not answering health checks."
    fi
    if pgrep -f "ollama" >/dev/null 2>&1; then
        echo "   ⚠️  Notice: Ollama is running in the background and may hold Apple Silicon GPU memory."
    fi
    exit 1
fi
