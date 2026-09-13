# ⚡ codex-local

> **Blazing-fast local inference for OpenAI Codex CLI on Apple Silicon (M1/M2/M3/M4).**  
> Run **Qwen3.8-27B** with near GPT-4 coding capabilities at **35–45+ tokens/second** locally, with full function-calling, streaming reasoning, and a 64k context window.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Apple Silicon](https://img.shields.io/badge/Platform-Apple%20Silicon%20(Metal)-lightgrey.svg)]()
[![Backend: llama.cpp](https://img.shields.io/badge/Backend-llama.cpp%20Metal-orange.svg)]()
[![Model: Qwen3.8--27B--GSQ--RCO](https://img.shields.io/badge/Model-Qwen3.8--27B--GSQ--RCO--MTP-green.svg)]()

---

## 🎯 What is this?

OpenAI's official **Codex CLI** includes experimental support for local open-source models via `--oss --local-provider`. However, out of the box on consumer Apple Silicon machines (16 GB – 32 GB unified memory), running local 27B models typically suffers from three fatal issues:

1. **Sluggishness (5–10 tok/s)**: Memory bandwidth saturation reading 16+ GB model weights for each generated token.
2. **Context Blowout (85,000 startup tokens)**: Codex dumps entire plugin and app schema catalogs on every turn, taking minutes just to ingest initial context.
3. **XML Tag Leakage & Broken Tools**: `<think>` and `<tool_call>` tags leak as raw text in assistant responses instead of executing functions, because generic chat templates do not parse grammar into OpenAI-compliant `tool_calls` JSON.

**`codex-local` solves all three.** It provides a production-grade automated setup and a smart supervisor wrapper that pairs **OpenAI Codex CLI** with a fine-tuned **`llama-server`** backend using state-of-the-art quantization, speculative decoding, and native Jinja tool-call grammars.

---

## 🚀 Performance Benchmarks

*Tested on Apple MacBook Pro M1 Max (32 GB Unified Memory)*:

| Metric | Stock Ollama (Q4_K_M) | `codex-local` (GSQ-RCO + MTP + Q4_0 KV) | Improvement |
| :--- | :--- | :--- | :--- |
| **Model Size in VRAM** | 16.8 GB | **11.3 GB** | **-33% RAM pressure** |
| **Generation Speed** | ~10.2 tok/s | **38.4 – 46.2 tok/s** | **~4x faster** ⚡ |
| **Prompt Ingestion Speed** | ~42 tok/s | **129.3 tok/s** | **~3x faster** |
| **Initial Prompt Overhead** | ~85,000 tokens | **~4,800 tokens** | **-94% prompt size** |
| **Speculative Acceptance (MTP)** | N/A | **75.8% – 96.6%** | **~2.7 tokens / step** |
| **Function Calling Reliability** | Broken (raw XML) | **100% Native OpenAI JSON** | Verified |

---

## 🧠 Architectural Insights & The 5 Lessons Learned

### 1. Breaking the 16 GB Threshold with GSQ-RCO Quantization
In local LLM inference, autoregressive generation is purely **memory bandwidth bound**: the GPU must read every single model weight byte from memory to produce a single token.
- Standard 4-bit (`Q4_K_M`) weighs **16.8 GB**, choking memory buses and leaving no room for KV cache on 16 GB or 32 GB Macs.
- We utilize **GSQ-RCO** (*Gumbel-Softmax Quantization with Riemannian Constrained Optimization*) developed by ISTA-DASLab: [`Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf`](https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF).
- At **11.28 GB** (3.44 bits/weight), it yields a **35–40% raw bandwidth speedup** while achieving **100% score parity** on coding benchmarks (*LiveCodeBench v6 score: 85.71*).

### 2. Multi-Token Prediction (MTP) Speculative Decoding
The model contains an integrated Multi-Token Prediction draft head.
- Rather than laboriously generating one token per forward pass, `llama-server` predicts **2 additional speculative tokens** in parallel (`--spec-type draft-mtp --spec-draft-n-max 2`).
- A single verification pass validates the draft tokens with an observed **75% to 96% acceptance rate**.
- This directly boosts output throughput from ~14 tok/s to **38–46+ tok/s** without requiring a separate draft model.

### 3. 4-bit KV Cache Compression (`--cache-type-k q4_0 --cache-type-v q4_0`)
At a 64,536 token context window, a standard 16-bit FP16 KV cache consumes over **16 GB of VRAM** solely for attention keys and values!
- Compressing the KV cache to 4-bit (`q4_0`) slashes cache memory down to **~4 GB**.
- Both model weights (11.3 GB) and full 64k KV cache (4 GB) fit within **~15.5 GB**, comfortably operating on Apple Silicon unified memory without memory pressure or swap.

### 4. Native Tool Calling & Thinking Extraction (`template.jinja`)
When Codex talks to local endpoints, generic `chatml` templates fail:
- Codex expects tool calls in `"tool_calls": [{"name": ..., "arguments": ...}]` and reasoning in `"reasoning_content"`.
- Without a proper Jinja template, `llama-server` emits raw `<tool_call>` XML into assistant `content`, causing Codex to print the XML code instead of executing tools.
- Furthermore, default Qwen Jinja templates crash with `System message must be at the beginning` when Codex injects contextual instructions during multi-turn chats.
- Our customized [`templates/template.jinja`](templates/template.jinja) combined with `--reasoning-format deepseek` formats function definitions cleanly, extracts `<think>...</think>` into `reasoning_content`, and permits multi-turn system prompts without exceptions.

### 5. The Context Ingestion Diet
By default, Codex CLI inspects and transmits schemas for all installed plugins and apps on startup, creating an **~85,000 token system prompt**.
- In [`config/config.toml`](config/config.toml), we set:
  ```toml
  [features]
  plugins = false
  recommended_plugins = false
  apps = false
  ```
- This shrinks initial context from 85k down to **~4.8k tokens**, enabling instant turn turnaround and preserving context space for actual code files.

---

## 📦 Quickstart

### Prerequisites
- **macOS** on Apple Silicon (M1, M2, M3, M4 — Pro/Max/Ultra or 16GB+ Air).
- [Homebrew](https://brew.sh) installed.
- [OpenAI Codex CLI](https://github.com/openai/codex) installed.

### One-Command Setup

Clone this repository and run the automated installer:

```bash
git clone https://github.com/jhiver/codex-local.git
cd codex-local
./install.sh
```

The installer will:
1. Verify Apple Silicon Metal compatibility.
2. Install `llama.cpp` (with Metal acceleration), `curl`, and `jq` via Homebrew.
3. Download the 11.28 GB `Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf` model from Hugging Face with resumable download support.
4. Deploy the Jinja template and initialize `~/.codex-local/config.toml`.
5. Configure the `codex-local` smart wrapper alias in your `~/.zshrc`.

---

## 💻 Usage

Once installed, simply run:

```bash
codex-local
```

### What happens behind the scenes:
1. **Daemon Auto-Detection**: The smart supervisor checks if `llama-server` is responding on `http://127.0.0.1:1234`.
2. **Auto-Start**: If offline, it starts `llama-server` as a background daemon with tuned Metal + MTP flags and waits until the model is loaded in Metal VRAM (2–4 seconds).
3. **Execution**: It launches Codex CLI configured with your local environment (`CODEX_HOME=~/.codex-local codex --oss --local-provider lmstudio -m "qwen3.8-27b-uncensored:latest"`).

### Management Commands

```bash
# Check if the server is healthy and view active model / context
codex-local status

# Follow live server logs (token rates, MTP acceptance %, KV cache usage)
codex-local logs

# Gracefully shut down the background server
codex-local stop

# Start the background server without launching Codex CLI
codex-local start
```

---

## ⚙️ Configuration Details

### `llama-server` Flags (`scripts/start-server.sh`)

```bash
llama-server \
  -m "$MODEL_PATH" \
  --alias "qwen3.8-27b-uncensored:latest" \
  -ngl 99 \                               # Offload 100% of layers to Metal GPU
  -c 65536 \                              # 64k token context window
  --cache-type-k q4_0 \                   # 4-bit KV Cache Key compression
  --cache-type-v q4_0 \                   # 4-bit KV Cache Value compression
  --spec-draft-type-k q4_0 \              # 4-bit Draft KV Cache
  --spec-draft-type-v q4_0 \
  -fa on \                                # Flash Attention for Apple Silicon
  --chat-template-file "$TEMPLATE_PATH" \ # Custom Jinja for Qwen tool calling
  --reasoning-format deepseek \           # Native reasoning_content parsing
  --spec-type draft-mtp \                 # Multi-Token Prediction speculative engine
  --spec-draft-n-max 2 \                  # 2 draft tokens per step
  --host 127.0.0.1 \
  --port 1234
```

### Custom Codex Configuration (`~/.codex-local/config.toml`)

```toml
model = "qwen3.8-27b-uncensored:latest"
model_context_window = 65536
model_auto_compact_token_limit = 58000
model_reasoning_effort = "medium"
personality = "pragmatic"

[features]
plugins = false
recommended_plugins = false
apps = false
multi_agent = false
```

---

## 🛠️ Troubleshooting

### Ollama GPU Contention
If you previously ran Ollama with a large model, it may hold GPU memory even when idle.
If `codex-local` fails to allocate Metal memory:
```bash
brew services stop ollama
# or
pkill -f ollama
```

### Port Conflict
`codex-local` defaults to port `1234` (the default port for LM Studio compatible endpoints in Codex). If another process is using port 1234:
```bash
lsof -i :1234
```

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
