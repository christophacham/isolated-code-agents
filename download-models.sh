#!/bin/bash
# Download Ollama models for RTX 5090 (32GB VRAM)

set -e

echo "=============================================="
echo "  Ollama Model Downloader - RTX 5090 Edition"
echo "=============================================="
echo ""

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo "⚠️  Ollama is not running. Starting it..."
    ollama serve &>/dev/null &
    sleep 3
fi

# Function to download a model if not already installed
download_model() {
    local model=$1
    local description=$2

    # Check if model exists
    if ollama list 2>/dev/null | grep -q "^${model}"; then
        echo "✅ $model - already installed"
    else
        echo "📥 Downloading $model..."
        echo "   $description"
        ollama pull "$model"
        echo "✅ $model - downloaded"
    fi
    echo ""
}

# Parse arguments
MINIMAL=false
ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal|-m)
            MINIMAL=true
            shift
            ;;
        --all|-a)
            ALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --minimal, -m    Download only qwen2.5-coder:32b"
            echo "  --all, -a        Download all 4 models"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Default: Downloads coder + reasoning models"
            echo ""
            echo "Available models:"
            echo "  qwen2.5-coder:32b  - Best coding model (~19GB)"
            echo "  qwen3:32b          - Dual mode thinking (~19GB)"
            echo "  deepseek-r1:32b    - Best reasoning (~20GB)"
            echo "  dolphin3:8b        - Uncensored (~5GB)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🦙 Checking installed models..."
echo ""

if $MINIMAL; then
    echo "📦 Minimal Mode: Coding model only"
    echo ""
    download_model "qwen2.5-coder:32b" "Best local coding model, 92 languages (~19GB)"

elif $ALL; then
    echo "📦 Full Mode: All 4 models"
    echo ""
    download_model "qwen2.5-coder:32b" "Best local coding model (~19GB)"
    download_model "qwen3:32b" "Dual mode thinking/non-thinking (~19GB)"
    download_model "deepseek-r1:32b" "Best local reasoning, chain-of-thought (~20GB)"
    download_model "dolphin3:8b" "Uncensored for unrestricted tasks (~5GB)"

else
    # Default: Core models (coder + reasoning)
    echo "📦 Default Mode: Coder + Reasoning"
    echo ""
    download_model "qwen2.5-coder:32b" "Best local coding model (~19GB)"
    download_model "deepseek-r1:32b" "Best local reasoning (~20GB)"
fi

echo "=============================================="
echo "  Download Complete!"
echo "=============================================="
echo ""
echo "📋 Installed models:"
ollama list
echo ""
echo "💡 Usage:"
echo "   ollama run qwen2.5-coder:32b"
echo "   ollama run deepseek-r1:32b"
