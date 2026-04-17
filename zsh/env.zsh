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

# Local-AI env (HF, Ollama, llama.cpp, LOCAL_AI_*) lives in llamactl now.
# The clone is expected under $DEV_STORAGE/repos/personal/llamactl by default;
# override $LLAMACTL_HOME to point elsewhere. When the clone is missing the
# local-AI variables simply stay unset and the rest of the environment is
# unaffected.
: "${LLAMACTL_HOME:=$DEV_STORAGE/repos/personal/llamactl}"
if [ -f "$LLAMACTL_HOME/shell/env.zsh" ]; then
  source "$LLAMACTL_HOME/shell/env.zsh"
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
  "$NODE_GYP_CACHE"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
