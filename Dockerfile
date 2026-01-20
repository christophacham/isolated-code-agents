# AI CLI Docker Container
# Claude Code + Qwen Code + Gemini CLI + Ollama + PAL MCP Server
# RTX 5090 Optimized (32GB VRAM)
# Based on: https://github.com/christophacham/ollama-rtx-setup
#
# Models are stored in /ollama-models volume for persistence across containers
#
# Includes Rust/WASM toolchain for AxisBlend and similar projects:
# - Rust 1.91+ with wasm32-unknown-unknown target
# - wasm-pack 0.13.1 for building Rust to WASM
# - pnpm 10.x package manager
# - cargo-watch for auto-rebuilding

FROM ollama/ollama:latest

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/zsh

# Set up locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    ripgrep \
    fzf \
    jq \
    vim \
    nano \
    htop \
    ca-certificates \
    gnupg \
    sudo \
    pciutils \
    zsh \
    fonts-powerline \
    fontconfig \
    tmux \
    tree \
    fd-find \
    bat \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for bat and fd
RUN ln -sf /usr/bin/batcat /usr/bin/bat 2>/dev/null || true && \
    ln -sf /usr/bin/fdfind /usr/bin/fd 2>/dev/null || true

# Install JetBrainsMono Nerd Font
RUN mkdir -p /usr/share/fonts/truetype/jetbrains-mono && \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -o /tmp/JetBrainsMono.tar.xz && \
    tar -xf /tmp/JetBrainsMono.tar.xz -C /usr/share/fonts/truetype/jetbrains-mono && \
    fc-cache -fv && \
    rm /tmp/JetBrainsMono.tar.xz

# Install Node.js 24.x (latest LTS "Krypton") via NodeSource with GPG verification
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm globally (latest 10.x)
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install -g pnpm@latest && \
    pnpm --version

# Verify Node.js installation
RUN node --version && npm --version

# Create non-root user for running CLIs (no sudo access)
RUN useradd -m -s /bin/zsh aiuser

# Create shared model directory (will be mounted as volume)
RUN mkdir -p /ollama-models && chown -R aiuser:aiuser /ollama-models

# Switch to aiuser for npm global installs
USER aiuser
WORKDIR /home/aiuser

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Oh My Zsh plugins
RUN git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab

# ============================================
# Rust/WASM Toolchain (for AxisBlend and similar projects)
# ============================================

# Install Rust via rustup (as aiuser)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/home/aiuser/.cargo/bin:${PATH}"

# Add WASM target for WebAssembly compilation
RUN rustup target add wasm32-unknown-unknown

# Install wasm-pack for building Rust to WASM
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Install cargo-watch for auto-rebuilding on file changes
RUN cargo install cargo-watch

# Verify Rust installation
RUN rustc --version && cargo --version && wasm-pack --version

# Configure Oh My Zsh and shell welcome
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc && \
    sed -i 's/plugins=(git)/plugins=(git docker zsh-syntax-highlighting zsh-autosuggestions fzf-tab)/g' ~/.zshrc && \
    echo '' >> ~/.zshrc && \
    echo '# PAL MCP Server aliases (runs in tmux background)' >> ~/.zshrc && \
    echo "alias pal='tmux has-session -t pal 2>/dev/null && echo \"PAL already running (use pal-attach to view)\" || (tmux new-session -d -s pal \"cd /home/aiuser/pal-mcp-server && /home/aiuser/pal-venv/bin/python server.py\" && echo \"PAL started in background (use pal-attach to view)\")'" >> ~/.zshrc && \
    echo "alias pal-attach='tmux attach -t pal'" >> ~/.zshrc && \
    echo "alias pal-stop='tmux kill-session -t pal 2>/dev/null && echo \"PAL stopped\" || echo \"PAL not running\"'" >> ~/.zshrc && \
    echo "alias pal-status='tmux has-session -t pal 2>/dev/null && echo \"PAL is running\" || echo \"PAL is not running\"'" >> ~/.zshrc && \
    echo '' >> ~/.zshrc && \
    echo '# Show welcome message' >> ~/.zshrc && \
    echo 'source /home/aiuser/shell-welcome.sh' >> ~/.zshrc && \
    echo '' >> ~/.bashrc && \
    echo '# PAL MCP Server aliases (runs in tmux background)' >> ~/.bashrc && \
    echo "alias pal='tmux has-session -t pal 2>/dev/null && echo \"PAL already running (use pal-attach to view)\" || (tmux new-session -d -s pal \"cd /home/aiuser/pal-mcp-server && /home/aiuser/pal-venv/bin/python server.py\" && echo \"PAL started in background (use pal-attach to view)\")'" >> ~/.bashrc && \
    echo "alias pal-attach='tmux attach -t pal'" >> ~/.bashrc && \
    echo "alias pal-stop='tmux kill-session -t pal 2>/dev/null && echo \"PAL stopped\" || echo \"PAL not running\"'" >> ~/.bashrc && \
    echo "alias pal-status='tmux has-session -t pal 2>/dev/null && echo \"PAL is running\" || echo \"PAL is not running\"'" >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Show welcome message' >> ~/.bashrc && \
    echo 'source /home/aiuser/shell-welcome.sh' >> ~/.bashrc

# Set up npm global directory for user
RUN mkdir -p /home/aiuser/.npm-global && \
    npm config set prefix '/home/aiuser/.npm-global'
ENV PATH="/home/aiuser/.npm-global/bin:${PATH}"

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code@latest

# Install Qwen Code CLI  
RUN npm install -g @qwen-code/qwen-code@latest

# Install Gemini CLI
RUN npm install -g @google/gemini-cli@latest

# Create Python virtual environment for PAL MCP
RUN python3 -m venv /home/aiuser/pal-venv
ENV PATH="/home/aiuser/pal-venv/bin:${PATH}"

# Clone and install PAL MCP Server
RUN git clone https://github.com/BeehiveInnovations/pal-mcp-server.git /home/aiuser/pal-mcp-server
WORKDIR /home/aiuser/pal-mcp-server

# Ensure we have the latest PAL MCP code
RUN git checkout main && git pull origin main

# Install PAL MCP dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Create configuration directories
RUN mkdir -p /home/aiuser/.claude \
             /home/aiuser/.gemini \
             /home/aiuser/.qwen \
             /home/aiuser/.ollama \
             /home/aiuser/pal-mcp-server/conf \
             /home/aiuser/scripts

# Switch back to root to copy config files
USER root

# Copy configuration files (local models only)
COPY --chown=aiuser:aiuser custom_models.json /home/aiuser/pal-mcp-server/conf/custom_models.json
COPY --chown=aiuser:aiuser pal.env /home/aiuser/pal-mcp-server/.env
COPY --chown=aiuser:aiuser claude_settings.json /home/aiuser/.claude/settings.json
COPY --chown=aiuser:aiuser gemini_settings.json /home/aiuser/.gemini/settings.json
COPY --chown=aiuser:aiuser qwen_settings.json /home/aiuser/.qwen/settings.json

# Copy helper scripts
COPY --chown=aiuser:aiuser entrypoint.sh /home/aiuser/entrypoint.sh
COPY --chown=aiuser:aiuser download-models.sh /home/aiuser/download-models.sh
COPY --chown=aiuser:aiuser shell-welcome.sh /home/aiuser/shell-welcome.sh
RUN chmod +x /home/aiuser/entrypoint.sh /home/aiuser/download-models.sh /home/aiuser/shell-welcome.sh

# Set working directory
WORKDIR /workspace

# Switch back to aiuser
USER aiuser

# ============================================
# RTX 5090 Optimizations (32GB VRAM)
# From: https://github.com/christophacham/ollama-rtx-setup
# ============================================
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Ollama optimizations
ENV OLLAMA_FLASH_ATTENTION=1
ENV OLLAMA_NUM_GPU=999
ENV OLLAMA_HOST=127.0.0.1:11434
ENV OLLAMA_MODELS=/ollama-models

# Healthcheck for Ollama server
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://127.0.0.1:11434/api/tags || exit 1

# Default command
ENTRYPOINT ["/home/aiuser/entrypoint.sh"]
CMD ["zsh"]
