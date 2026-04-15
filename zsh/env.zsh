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

if [ -n "$ZSH_VERSION" ]; then
  typeset -U path PATH
fi

export WORKSSD="/Volumes/WorkSSD"
export DEV_STORAGE="$HOME/DevStorage"
export DEV_STORAGE_FALLBACK="$HOME/.devstorage"
export DEV_STORAGE_REPAIR_BACKUP=""

devstorage_prepare_fallback() {
  mkdir -p "$DEV_STORAGE_FALLBACK"/{cache,tmp,fnm,ai-models,repos,docker,bin}
  mkdir -p "$DEV_STORAGE_FALLBACK"/cache/{brew,pip,uv,ccache,npm,turbo,nx,node-gyp}
  mkdir -p "$DEV_STORAGE_FALLBACK"/ai-models/ollama
  mkdir -p "$DEV_STORAGE_FALLBACK"/repos/{work,personal}
}

devstorage_target() {
  if [ -d "$WORKSSD" ]; then
    printf '%s\n' "$WORKSSD"
  else
    printf '%s\n' "$DEV_STORAGE_FALLBACK"
  fi
}

devstorage_mode_for_target() {
  if [ "$1" = "$WORKSSD" ]; then
    printf 'external\n'
  else
    printf 'local\n'
  fi
}

devstorage_relink() {
  local target="$1"

  rm -f "$DEV_STORAGE"
  ln -s "$target" "$DEV_STORAGE"
}

devstorage_switch() {
  local target current_target backup_path

  devstorage_prepare_fallback
  target="$(devstorage_target)"

  if [ -L "$DEV_STORAGE" ]; then
    current_target="$(readlink "$DEV_STORAGE" 2>/dev/null || true)"
    if [ "$current_target" != "$target" ]; then
      devstorage_relink "$target"
    fi
  elif [ -e "$DEV_STORAGE" ]; then
    if [ "$target" = "$WORKSSD" ]; then
      backup_path="$HOME/.devstorage-legacy-$(date +%Y%m%d-%H%M%S)"
      mv "$DEV_STORAGE" "$backup_path"
      export DEV_STORAGE_REPAIR_BACKUP="$backup_path"
      devstorage_relink "$target"
    fi
  else
    ln -s "$target" "$DEV_STORAGE"
  fi

  export DEV_STORAGE_MODE="$(devstorage_mode_for_target "$target")"
}

if ! devstorage_switch >/dev/null 2>&1; then
  if [ -L "$DEV_STORAGE" ] && [ "$(readlink "$DEV_STORAGE" 2>/dev/null)" = "$WORKSSD" ]; then
    export DEV_STORAGE_MODE="external"
  else
    export DEV_STORAGE_MODE="local"
  fi
fi

if [ -n "$ZSH_VERSION" ]; then
  path=(
    "$HOME/.opencode/bin"
    "$HOME/bin"
    "$HOME/.local/bin"
    "$DEV_STORAGE/bin"
    $path
  )

  if [ -d "$HOME/.lmstudio/bin" ]; then
    path+=("$HOME/.lmstudio/bin")
  fi

  export PATH
else
  export PATH="$HOME/.opencode/bin:$HOME/bin:$HOME/.local/bin:$DEV_STORAGE/bin:$PATH"

  if [ -d "$HOME/.lmstudio/bin" ]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
  fi
fi

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

if [ -z "$LLAMA_CPP_MACHINE_PROFILE" ]; then
  _llama_cpp_hw_mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"

  case "$_llama_cpp_hw_mem_bytes" in
    ''|*[!0-9]*)
      export LLAMA_CPP_MACHINE_PROFILE="macbook-pro-48g"
      ;;
    *)
      if [ "$_llama_cpp_hw_mem_bytes" -le 17179869184 ]; then
        export LLAMA_CPP_MACHINE_PROFILE="mac-mini-16g"
      elif [ "$_llama_cpp_hw_mem_bytes" -le 34359738368 ]; then
        export LLAMA_CPP_MACHINE_PROFILE="balanced"
      else
        export LLAMA_CPP_MACHINE_PROFILE="macbook-pro-48g"
      fi
      ;;
  esac

  unset _llama_cpp_hw_mem_bytes
fi

if [ -z "$LLAMA_CPP_GEMMA_CTX_SIZE" ]; then
  case "$LLAMA_CPP_MACHINE_PROFILE" in
    mac-mini-16g)
      export LLAMA_CPP_GEMMA_CTX_SIZE="16384"
      ;;
    balanced)
      export LLAMA_CPP_GEMMA_CTX_SIZE="24576"
      ;;
    *)
      export LLAMA_CPP_GEMMA_CTX_SIZE="32768"
      ;;
  esac
fi

if [ "$LLAMA_CPP_MACHINE_PROFILE" = "mac-mini-16g" ]; then
  if [ -f "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
  else
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
  fi
elif [ "$LLAMA_CPP_MACHINE_PROFILE" = "balanced" ]; then
  if [ -f "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
  else
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
  fi
else
  if [ -f "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
  elif [ -f "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" ]; then
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
  else
    export LLAMA_CPP_DEFAULT_MODEL="gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
  fi
fi

export LLAMA_CPP_SERVER_ALIAS="local"

export LLAMA_CACHE="$LLAMA_CPP_CACHE"
export LOCAL_AI_LMSTUDIO_HOST="127.0.0.1"
export LOCAL_AI_LMSTUDIO_PORT="1234"
export LOCAL_AI_LMSTUDIO_BASE_URL="http://$LOCAL_AI_LMSTUDIO_HOST:$LOCAL_AI_LMSTUDIO_PORT/v1"
export LOCAL_AI_LLAMA_CPP_BASE_URL="http://$LLAMA_CPP_HOST:$LLAMA_CPP_PORT/v1"
export LOCAL_AI_RUNTIME_DIR="$DEV_STORAGE/ai-models/local-ai"
export LOCAL_AI_ENABLE_THINKING="${LOCAL_AI_ENABLE_THINKING:-false}"

LOCAL_AI_SOURCE_MODEL="${LOCAL_AI_SOURCE_MODEL:-$LLAMA_CPP_DEFAULT_MODEL}"

if [ -z "$LOCAL_AI_PROVIDER" ]; then
  export LOCAL_AI_PROVIDER="llama.cpp"
fi

export LOCAL_AI_CONTEXT_LENGTH="${LOCAL_AI_CONTEXT_LENGTH:-$LLAMA_CPP_GEMMA_CTX_SIZE}"

case "$LOCAL_AI_PROVIDER" in
  lmstudio)
    export LOCAL_AI_PROVIDER_URL="$LOCAL_AI_LMSTUDIO_BASE_URL"
    export LOCAL_AI_API_KEY="${LM_API_TOKEN:-local}"
    export LOCAL_AI_MODEL="${LOCAL_AI_MODEL:-local/${LOCAL_AI_SOURCE_MODEL%%/*}}"
    ;;
  *)
    export LOCAL_AI_PROVIDER="llama.cpp"
    export LOCAL_AI_PROVIDER_URL="$LOCAL_AI_LLAMA_CPP_BASE_URL"
    export LOCAL_AI_API_KEY="local"
    export LOCAL_AI_MODEL="${LOCAL_AI_MODEL:-$LLAMA_CPP_SERVER_ALIAS}"
    ;;
esac

export OPENAI_BASE_URL="$LOCAL_AI_PROVIDER_URL"
export OPENAI_API_KEY="$LOCAL_AI_API_KEY"

if [ -d "$LLAMA_CPP_BIN" ]; then
  if [ -n "$ZSH_VERSION" ]; then
    path=("$LLAMA_CPP_BIN" $path)
    export PATH
  else
    export PATH="$LLAMA_CPP_BIN:$PATH"
  fi
fi

export BUN_INSTALL="$HOME/.bun"
if [ -n "$ZSH_VERSION" ]; then
  path=("$BUN_INSTALL/bin" $path)
  export PATH
else
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

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
  "$LLAMA_CPP_LOGS" \
  "$LOCAL_AI_RUNTIME_DIR"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
