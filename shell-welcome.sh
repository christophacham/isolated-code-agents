#!/bin/bash
# Shell welcome message - shows available commands

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}   AI CLI Docker Container${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""
echo -e "${CYAN}Available AI CLIs:${NC}"
echo "   claude   - Claude Code CLI (Anthropic)"
echo "   qwen     - Qwen Code CLI (Alibaba)"
echo "   gemini   - Gemini CLI (Google)"
echo "   ollama   - Local LLM server"
echo ""
echo -e "${CYAN}PAL MCP Server:${NC}"
echo "   pal         - Start PAL server in background (tmux)"
echo "   pal-attach  - Attach to see server output"
echo "   pal-stop    - Stop the PAL server"
echo "   pal-status  - Check if PAL is running"
echo ""
echo -e "${CYAN}Ollama Commands:${NC}"
echo "   ~/download-models.sh       - Download models"
echo "   ~/download-models.sh --all - Download all 4 models"
echo "   ollama run <model>         - Run a model"
echo "   ollama list                - List all models"
echo ""
echo -e "${CYAN}Development Toolchains:${NC}"
echo "   rustc / cargo       - Rust compiler & package manager"
echo "   wasm-pack build     - Build Rust to WASM"
echo "   go build            - Go compiler"
echo "   gcc / g++           - C/C++ compilers (GNU)"
echo "   clang / clang++     - C/C++ compilers (LLVM)"
echo "   gdb                 - GNU debugger"
echo "   pnpm install        - Install JS dependencies"
echo ""
echo -e "${CYAN}PAL MCP in any CLI:${NC}"
echo '   "Use pal to analyze this with deepseek"'
echo '   "Use pal codereview with coder to review this"'
echo ""
echo -e "${CYAN}==================================================${NC}"
echo ""
