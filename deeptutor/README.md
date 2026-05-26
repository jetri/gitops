# DeepTutor + vLLM (Qwen2.5-VL-32B)

Self-hosted AI tutor running on a gaming PC with an NVIDIA 5090 (32GB VRAM).

## Prerequisites

- NVIDIA GPU with 32GB+ VRAM (RTX 5090)
- Docker with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- ~20GB disk space for the model (downloaded on first run)

## Quick Start

```bash
cd deeptutor
docker compose up -d
```

First startup takes 10-20 minutes as vLLM downloads the model weights.
Monitor progress with:

```bash
docker logs -f vllm
```

Once vLLM shows `Uvicorn running on http://0.0.0.0:8000`, open DeepTutor:

- **DeepTutor UI**: http://localhost:3782

## Configure DeepTutor to use vLLM

In the DeepTutor web UI, go to **Settings** and configure the LLM provider:

- **Provider**: OpenAI-compatible
- **Base URL**: `http://vllm:8000/v1`
- **API Key**: `sk-no-key-required`
- **Model**: `qwen-vl-32b`

## Configure Embedding Model (for Knowledge Hub / RAG)

The stack includes a CPU-based embedding server using `BAAI/bge-m3` (multilingual: Chinese + English).
In DeepTutor settings, configure the embedding provider:

- **Provider**: OpenAI-compatible
- **Base URL**: `http://embeddings:80/v1`
- **API Key**: `sk-no-key-required`
- **Model**: `BAAI/bge-m3`

You can then upload curriculum PDFs to the Knowledge Hub and DeepTutor will
use RAG to pull relevant content into tutoring conversations.

## Model Details

| Setting | Value |
|---|---|
| Model | Qwen2.5-VL-32B-Instruct-AWQ |
| Quantization | AWQ Marlin (4-bit) |
| VRAM usage | ~16GB weights + ~16GB KV cache |
| Max context | 32,768 tokens |
| Vision | Images (up to 4 per prompt) |
| Languages | English, Chinese, 29+ others |

## Volumes

| Path | Purpose |
|---|---|
| `huggingface-cache` | Model weights (Docker named volume) |
| `./data/user` | DeepTutor user settings and config |
| `./data/memory` | DeepTutor persistent memory |
| `./data/knowledge_bases` | Uploaded curriculum documents (RAG) |

## Useful Commands

```bash
# Stop everything
docker compose down

# View vLLM logs
docker logs -f vllm

# View DeepTutor logs
docker logs -f deeptutor

# Restart vLLM only (e.g. after config change)
docker compose restart vllm

# Test vLLM API directly
curl http://localhost:8000/v1/models

# Test with a prompt
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen-vl-32b", "messages": [{"role": "user", "content": "What is 1/3 + 1/4?"}]}'
```
