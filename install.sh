#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# codex-local installer for macOS (Apple Silicon M1/M2/M3/M4)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="${MODEL_DIR:-$HOME/models}"
MODEL_FILENAME="Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored-v1.1.gguf"
MODEL_PATH="$MODEL_DIR/$MODEL_FILENAME"
MODEL_URL="https://huggingface.co/RentedNoodle/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored/resolve/main/$MODEL_FILENAME"
EXPECTED_BYTES=10466420544

echo "============================================================"
echo "🍏 Setting up codex-local for Apple Silicon Metal GPU"
echo "============================================================"

# 1. Platform Check
OS="$(uname -s)"
IS_ARM64=0
if [[ "$(uname -m)" == "arm64" ]] || [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == "1" ]]; then
    IS_ARM64=1
fi

if [[ "$OS" != "Darwin" || "$IS_ARM64" -ne 1 ]]; then
    echo "⚠️  Warning: This setup is tuned specifically for Apple Silicon (macOS arm64)."
    echo "   Detected: OS=$OS. Metal acceleration and MTP flags may not work as expected."
else
    echo "   ✅ Apple Silicon detected ($(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "ARM64"))"
fi

# 2. Homebrew Check
if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Error: Homebrew is required but not found in PATH." >&2
    echo "   Install Homebrew from: https://brew.sh" >&2
    exit 1
fi

# 3. Check / Install llama.cpp & tools
echo "📦 Checking dependencies..."
if ! command -v llama-server >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/llama-server" ]]; then
    echo "   Installing llama.cpp via Homebrew..."
    brew install llama.cpp
else
    echo "   ✅ llama-server is installed"
fi

for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "   Installing $tool via Homebrew..."
        brew install "$tool"
    fi
done

# 4. Model Directory & Download
mkdir -p "$MODEL_DIR"
cp "$SCRIPT_DIR/templates/template.jinja" "$MODEL_DIR/template.jinja"

NEED_DOWNLOAD=1
if [[ -f "$MODEL_PATH" ]]; then
    ACTUAL_BYTES=$(stat -f%z "$MODEL_PATH" 2>/dev/null || stat -c%s "$MODEL_PATH" 2>/dev/null || echo 0)
    if [[ "$ACTUAL_BYTES" -ge "$EXPECTED_BYTES" ]]; then
        echo "   ✅ Model file verified: $MODEL_PATH (~11.3 GB)"
        NEED_DOWNLOAD=0
    else
        echo "   ⚠️  Found incomplete model file ($ACTUAL_BYTES bytes). Resuming download..."
    fi
fi

if [[ $NEED_DOWNLOAD -eq 1 ]]; then
    echo ""
    echo "📥 Downloading Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf (~11.3 GB) from Hugging Face..."
    echo "   URL: $MODEL_URL"
    echo "   Destination: $MODEL_PATH"
    echo "   (Download supports resuming if interrupted)"
    echo ""
    curl -L -C - --retry 5 --progress-bar -o "$MODEL_PATH" "$MODEL_URL"
    echo "   ✅ Model download complete!"
fi

# 5. Initialize Codex Local Configuration
CODEX_HOME_DIR="$HOME/.codex-local"
mkdir -p "$CODEX_HOME_DIR"

if [[ ! -f "$CODEX_HOME_DIR/config.toml" ]]; then
    echo "⚙️  Creating $CODEX_HOME_DIR/config.toml..."
    cp "$SCRIPT_DIR/config/config.toml" "$CODEX_HOME_DIR/config.toml"
    
    # Import trusted projects from primary Codex config if present
    if [[ -f "$HOME/.codex/config.toml" ]]; then
        grep -A 2 '\[projects\.' "$HOME/.codex/config.toml" >> "$CODEX_HOME_DIR/config.toml" 2>/dev/null || true
    fi
    echo "   ✅ Configuration initialized with prompt ingestion diet"
else
    echo "   ✅ Existing configuration found in $CODEX_HOME_DIR/config.toml"
fi

if [[ -f "$HOME/.codex/auth.json" && ! -e "$CODEX_HOME_DIR/auth.json" ]]; then
    ln -s "$HOME/.codex/auth.json" "$CODEX_HOME_DIR/auth.json" 2>/dev/null || true
    echo "   ✅ Linked auth.json to preserve workspace permissions"
fi

# 6. Install CLI binary or shell alias
BIN_TARGET="$HOME/.local/bin/codex-local"
mkdir -p "$HOME/.local/bin"

ln -sf "$SCRIPT_DIR/bin/codex-local" "$BIN_TARGET"
chmod +x "$SCRIPT_DIR/bin/codex-local" "$SCRIPT_DIR/scripts/"*.sh

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

# Ensure alias points to the smart wrapper in shell RC
ALIAS_CMD="alias codex-local=\"$SCRIPT_DIR/bin/codex-local\""
if ! grep -q "codex-local" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# codex-local launcher" >> "$SHELL_RC"
    echo "$ALIAS_CMD" >> "$SHELL_RC"
    echo "   ✅ Added 'codex-local' alias to $SHELL_RC"
else
    # Update existing alias if it's the old inline one
    sed -i '' "s|alias codex-local=.*|$ALIAS_CMD|" "$SHELL_RC" 2>/dev/null || true
    echo "   ✅ Updated 'codex-local' alias in $SHELL_RC"
fi

echo ""
echo "============================================================"
echo "🎉 Setup Complete!"
echo "============================================================"
echo "To start using your lightning-fast local Codex:"
echo ""
echo "  1. Reload your shell:  source $SHELL_RC"
echo "  2. Run Codex locally:  codex-local"
echo ""
echo "Helper management commands:"
echo "  - codex-local status   (Check server health and loaded model)"
echo "  - codex-local logs     (View live llama-server logs)"
echo "  - codex-local stop     (Gracefully stop the server)"
echo "  - codex-local start    (Start the daemon manually)"
echo "============================================================"
