# =========================================================
# ENVIRONMENT
# =========================================================

export ZSH="$HOME/.oh-my-zsh"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

export EDITOR="code-insiders --wait"
export VISUAL="$EDITOR"

export STARSHIP_CONFIG="$HOME/.config/starship.toml"

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export WORKSSD="/Volumes/WorkSSD"
export DEV_STORAGE="$HOME/DevStorage"

if [ -x "$HOME/bin/devstorage-switch" ]; then
  "$HOME/bin/devstorage-switch" >/dev/null 2>&1
fi

if [ -L "$DEV_STORAGE" ] && [ "$(readlink "$DEV_STORAGE")" = "$WORKSSD" ]; then
  export DEV_STORAGE_MODE="external"
else
  export DEV_STORAGE_MODE="local"
fi

export PATH="$HOME/bin:$HOME/.local/bin:$DEV_STORAGE/bin:$PATH"
export PATH="$PATH:$HOME/.lmstudio/bin"
export PATH="$HOME/.opencode/bin:$PATH"

export HOMEBREW_CACHE="$DEV_STORAGE/cache/brew"
export PIP_CACHE_DIR="$DEV_STORAGE/cache/pip"
export UV_CACHE_DIR="$DEV_STORAGE/cache/uv"
export CCACHE_DIR="$DEV_STORAGE/cache/ccache"
export npm_config_cache="$DEV_STORAGE/cache/npm"
export TURBO_CACHE_DIR="$DEV_STORAGE/cache/turbo"
export NX_CACHE_DIRECTORY="$DEV_STORAGE/cache/nx"
export NODE_GYP_CACHE="$DEV_STORAGE/cache/node-gyp"

export FNM_DIR="$DEV_STORAGE/fnm"

export HF_HOME="$DEV_STORAGE/cache/huggingface"
export HUGGINGFACE_HUB_CACHE="$HF_HOME/hub"

export OLLAMA_MODELS="$DEV_STORAGE/ai-models/ollama"

export LLAMA_CPP_SRC="$DEV_STORAGE/src/llama.cpp"
export LLAMA_CPP_BIN="$LLAMA_CPP_SRC/build/bin"

export LLAMA_CPP_ROOT="$DEV_STORAGE/ai-models/llama.cpp"
export LLAMA_CPP_MODELS="$LLAMA_CPP_ROOT/models"
export LLAMA_CPP_CACHE="$LLAMA_CPP_ROOT/.cache"
export LLAMA_CPP_LOGS="$DEV_STORAGE/logs/llama.cpp"

export LLAMA_CPP_HOST="127.0.0.1"
export LLAMA_CPP_PORT="8080"
export LLAMA_CPP_DEFAULT_MODEL="gemma-3-4b-it-Q4_K_M.gguf"
export LLAMA_CPP_SERVER_ALIAS="local"

export LLAMA_CACHE="$LLAMA_CPP_CACHE"

if [ -d "$LLAMA_CPP_BIN" ]; then
  export PATH="$LLAMA_CPP_BIN:$PATH"
fi

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

mkdir -p \
  "$HOME/.cache/zsh" \
  "$FNM_DIR" \
  "$HOMEBREW_CACHE" \
  "$PIP_CACHE_DIR" \
  "$UV_CACHE_DIR" \
  "$CCACHE_DIR" \
  "$npm_config_cache" \
  "$TURBO_CACHE_DIR" \
  "$NX_CACHE_DIRECTORY" \
  "$NODE_GYP_CACHE" \
  "$HF_HOME" \
  "$HUGGINGFACE_HUB_CACHE" \
  "$OLLAMA_MODELS" \
  "$LLAMA_CPP_MODELS" \
  "$LLAMA_CPP_CACHE" \
  "$LLAMA_CPP_LOGS"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
