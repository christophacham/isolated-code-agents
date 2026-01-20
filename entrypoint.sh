#!/bin/bash
# AI CLI Docker Container Entrypoint
# Starts Ollama server and provides access to Claude, Qwen, Gemini CLIs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}   AI CLI Docker Container${NC}"
echo -e "${CYAN}   Claude Code | Qwen Code | Gemini CLI | Ollama${NC}"
echo -e "${CYAN}   with PAL MCP Server (Local + OpenRouter)${NC}"
echo -e "${CYAN}   RTX 5090 Optimized (32GB VRAM)${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""

# Check GPU availability
if command -v nvidia-smi &> /dev/null; then
    echo -e "🎮 ${GREEN}NVIDIA GPU detected:${NC}"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader 2>/dev/null | while read line; do
        echo "   $line"
    done
else
    echo -e "⚠️  ${YELLOW}No NVIDIA GPU detected (CPU mode)${NC}"
fi
echo ""

# Start Ollama server
echo "🦙 Starting Ollama server..."

# Kill any existing ollama process
pkill -f "ollama serve" 2>/dev/null || true
sleep 1

# Start Ollama in background with RTX 5090 optimizations
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_NUM_GPU=999
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_MODELS=/ollama-models

ollama serve &>/dev/null &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo -n "   Waiting for Ollama to start"
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        echo ""
        echo -e "   ${GREEN}✅ Ollama running at http://localhost:11434${NC}"
        break
    fi
    echo -n "."
    sleep 1
done

# Check if Ollama started successfully
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo ""
    echo -e "   ${YELLOW}⚠️  Ollama may not have started properly${NC}"
fi

# List installed models
echo ""
MODELS=$(ollama list 2>/dev/null | tail -n +2 | head -10)
if [ -n "$MODELS" ]; then
    MODEL_COUNT=$(echo "$MODELS" | wc -l)
    echo -e "   📦 ${GREEN}${MODEL_COUNT} model(s) installed:${NC}"
    echo "$MODELS" | while read line; do
        model=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $3}')
        echo "      • ${model} (${size})"
    done | head -10
    if [ $MODEL_COUNT -gt 10 ]; then
        echo "      ... and $((MODEL_COUNT - 10)) more"
    fi
else
    echo -e "   ${YELLOW}📦 No models installed${NC}"
    echo ""
    echo "   To download recommended models, run:"
    echo "      ~/download-models.sh"
fi
echo ""

# Display RTX 5090 optimizations
echo -e "⚡ ${CYAN}RTX 5090 Optimizations Active:${NC}"
echo "   OLLAMA_FLASH_ATTENTION=1"
echo "   OLLAMA_NUM_GPU=999 (full GPU offload)"
echo ""

# PAL MCP Server is pre-configured in the container
echo -e "🔧 ${CYAN}PAL MCP Server:${NC}"
echo -e "   ${GREEN}✅ Pre-configured for Claude, Qwen, and Gemini${NC}"
echo ""

# Display available CLIs
echo -e "📦 ${CYAN}Available AI CLIs:${NC}"
echo "   • claude   - Claude Code CLI (Anthropic)"
echo "   • qwen     - Qwen Code CLI (Alibaba)"
echo "   • gemini   - Gemini CLI (Google)"
echo "   • ollama   - Local LLM server"
echo ""

# Display Rust/WASM toolchain info
echo -e "🦀 ${CYAN}Rust/WASM Toolchain:${NC}"
RUST_VER=$(rustc --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
WASM_VER=$(wasm-pack --version 2>/dev/null | cut -d' ' -f2 || echo "not found")
PNPM_VER=$(pnpm --version 2>/dev/null || echo "not found")
echo "   Rust: ${RUST_VER} | wasm-pack: ${WASM_VER} | pnpm: ${PNPM_VER}"
echo ""


# Display workspace info
if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
    file_count=$(ls -1 /workspace 2>/dev/null | wc -l)
    echo -e "📁 ${GREEN}Workspace mounted at /workspace${NC}"
    echo "   Files: ${file_count} items"
else
    echo -e "⚠️  ${YELLOW}Workspace is empty or not mounted${NC}"
    echo "   Mount your code folder to /workspace"
fi
echo ""

# Display model volume info
if [ -d "/ollama-models" ]; then
    model_size=$(du -sh /ollama-models 2>/dev/null | cut -f1)
    echo -e "💾 ${CYAN}Model Storage:${NC} /ollama-models (${model_size:-empty})"
    echo "   Models persist across container restarts"
fi
echo ""

echo -e "${CYAN}💡 Quick Start:${NC}"
echo "   cd /workspace"
echo "   claude    # Start Claude Code with PAL MCP"
echo "   qwen      # Start Qwen Code with PAL MCP"
echo "   gemini    # Start Gemini CLI with PAL MCP"
echo ""
echo -e "${CYAN}🦙 Ollama Commands:${NC}"
echo "   ~/download-models.sh       # Download models"
echo "   ~/download-models.sh --all # Download all 4 models"
echo ""
echo "   ollama run qwen2.5-coder:32b   # Run coder"
echo "   ollama run deepseek-r1:32b     # Run reasoning"
echo "   ollama list                    # List all models"
echo ""
echo -e "${CYAN}🦀 Rust/WASM (for AxisBlend etc):${NC}"
echo "   pnpm install && pnpm wasm      # Build WASM"
echo "   pnpm dev:full                  # Dev + auto-rebuild"
echo ""
echo -e "${CYAN}🤖 PAL MCP in any CLI:${NC}"
echo '   "Use pal to analyze this with deepseek"'
echo '   "Use pal codereview with coder to review this"'
echo '   "Get consensus from r1 and coder on this approach"'
echo ""
echo -e "${CYAN}==================================================${NC}"
echo ""

# Change to workspace directory if it exists
if [ -d "/workspace" ]; then
    cd /workspace
fi

# Handle shutdown gracefully
cleanup() {
    echo ""
    echo "Shutting down Ollama..."
    kill $OLLAMA_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Execute the provided command or drop into bash
exec "$@"
