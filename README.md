# Isolated Code Agents

AI coding assistants that can run shell commands and modify files. That's powerful, but risky. This runs them in a Docker container so they can't touch your actual system.

## Why

Claude, Qwen, Gemini - these tools can execute arbitrary code. They're useful, but you're giving an AI full shell access. If it hallucinates a bad command, misunderstands your intent, or just makes a mistake, it runs on your machine.

This container isolates that risk. The AI can do whatever it wants inside the container. Your host system stays untouched. If something goes wrong, delete the container and start fresh.

## What's Inside

- **Claude Code** - Anthropic's CLI
- **Qwen Code** - Alibaba's CLI
- **Gemini CLI** - Google's CLI
- **Ollama** - Local models (no API costs, full privacy)
- **PAL MCP Server** - Lets the AIs use local Ollama models as tools

Optimized for RTX 5090 (32GB VRAM) but works on any NVIDIA GPU or CPU-only.

## Get Started

1. Clone this repo
2. Add your API keys to environment:
   ```
   export ANTHROPIC_API_KEY=your-key
   export GOOGLE_API_KEY=your-key
   export DASHSCOPE_API_KEY=your-key  # for Qwen
   ```
3. Run:
   ```
   docker compose up -d
   docker exec -it ai-cli zsh
   ```
4. Inside the container:
   ```
   cd /workspace
   claude   # or qwen, or gemini
   ```

## Workspace

Mount your code to `/workspace`. The container can read and write there, but nowhere else on your system.

```yaml
volumes:
  - ./your-project:/workspace
```

## Local Models

Don't want to send code to external APIs? Use Ollama:

```
~/download-models.sh --all   # downloads recommended models
ollama run qwen2.5-coder:32b
```

Then tell any AI: "Use pal to analyze this with the local coder model"

## PAL MCP

PAL lets the cloud AIs delegate to local models. Useful for:
- Keeping sensitive code local
- Getting a second opinion without extra API costs
- Using reasoning models (deepseek-r1) alongside coding models

Start it manually with `pal` command, or it auto-starts when configured in the CLI settings.

## The Point

Run AI coding tools without giving them the keys to your entire machine. That's it.
