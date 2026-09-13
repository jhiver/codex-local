#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configurable options
MODEL_DIR="${MODEL_DIR:-$HOME/models}"
MODEL_PATH="${MODEL_PATH:-$MODEL_DIR/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf}"
TEMPLATE_PATH="${TEMPLATE_PATH:-$ROOT_DIR/templates/template.jinja}"
LOG_PATH="${LOG_PATH:-$MODEL_DIR/llama-server.log}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-1234}"
CTX_SIZE="${CTX_SIZE:-65536}"
MODEL_ALIAS="${MODEL_ALIAS:-qwen3.8-27b-uncensored:latest}"

# Locate llama-server binary
if command -v llama-server >/dev/null 2>&1; then
    LLAMA_BIN="$(command -v llama-server)"
elif [[ -x "/opt/homebrew/bin/llama-server" ]]; then
    LLAMA_BIN="/opt/homebrew/bin/llama-server"
elif [[ -x "/usr/local/bin/llama-server" ]]; then
    LLAMA_BIN="/usr/local/bin/llama-server"
else
    echo "❌ Error: 'llama-server' not found in PATH or /opt/homebrew/bin." >&2
    echo "👉 Run 'brew install llama.cpp' first." >&2
    exit 1
fi

# Verify model file
if [[ ! -f "$MODEL_PATH" ]]; then
    echo "❌ Error: Model file not found at: $MODEL_PATH" >&2
    echo "👉 Run './install.sh' to download the model or set MODEL_PATH manually." >&2
    exit 1
fi

# Verify template file
if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "❌ Error: Jinja template file not found at: $TEMPLATE_PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG_PATH")"

echo "============================================================"
echo "🚀 Starting llama-server"
echo "   Model:    $MODEL_PATH"
echo "   Endpoint: http://${HOST}:${PORT}/v1"
echo "   Context:  ${CTX_SIZE} tokens (4-bit KV Cache)"
echo "   Engine:   Metal GPU (all layers) + MTP Speculative Decoding"
echo "   Logging:  $LOG_PATH"
echo "============================================================"

exec "$LLAMA_BIN" \
  -m "$MODEL_PATH" \
  --alias "$MODEL_ALIAS" \
  -ngl 99 \
  -c "$CTX_SIZE" \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --spec-draft-type-k q4_0 \
  --spec-draft-type-v q4_0 \
  -fa on \
  --chat-template-file "$TEMPLATE_PATH" \
  --reasoning-format deepseek \
  --spec-type draft-mtp \
  --spec-draft-n-max 2 \
  --host "$HOST" \
  --port "$PORT" "$@" 2>&1 | tee -a "$LOG_PATH"
