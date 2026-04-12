# =========================================================
# ZSHRC v9 - stable dev environment with DevStorage fallback
# =========================================================

# -----------------------------
# Base environment
# -----------------------------
export ZSH="$HOME/.oh-my-zsh"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

export EDITOR="code-insiders --wait"
export VISUAL="$EDITOR"

export STARSHIP_CONFIG="$HOME/.config/starship.toml"

# -----------------------------
# Homebrew
# -----------------------------
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# -----------------------------
# DevStorage detection
# -----------------------------
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

# -----------------------------
# Tool caches
# -----------------------------
export HOMEBREW_CACHE="$DEV_STORAGE/cache/brew"
export PIP_CACHE_DIR="$DEV_STORAGE/cache/pip"
export UV_CACHE_DIR="$DEV_STORAGE/cache/uv"
export CCACHE_DIR="$DEV_STORAGE/cache/ccache"
export npm_config_cache="$DEV_STORAGE/cache/npm"
export TURBO_CACHE_DIR="$DEV_STORAGE/cache/turbo"
export NX_CACHE_DIRECTORY="$DEV_STORAGE/cache/nx"
export NODE_GYP_CACHE="$DEV_STORAGE/cache/node-gyp"

export FNM_DIR="$DEV_STORAGE/fnm"
export OLLAMA_MODELS="$DEV_STORAGE/ai-models/ollama"
export LLAMA_CPP_MODELS="$DEV_STORAGE/ai-models/llama.cpp"
export LLAMA_CPP_LOGS="$DEV_STORAGE/logs/llama.cpp"
export LLAMA_CPP_HOST="127.0.0.1"
export LLAMA_CPP_PORT="8080"
export LLAMA_CPP_DEFAULT_MODEL="gemma-3-4b-it-Q4_K_M.gguf"
export LLAMA_CPP_SERVER_ALIAS="local"
export HF_HOME="$DEV_STORAGE/cache/huggingface"
export HUGGINGFACE_HUB_CACHE="$HF_HOME/hub"

# -----------------------------
# PATH
# -----------------------------
export PATH="$HOME/bin:$HOME/.local/bin:$DEV_STORAGE/bin:$PATH"

setopt NO_BANG_HIST

# =========================================================
# OH MY ZSH
# =========================================================

DISABLE_UNTRACKED_FILES_DIRTY="true"
ZSH_THEME=""
ZSH_DISABLE_COMPFIX=true

plugins=(
  git
  macos
  brew
  npm
  docker
  docker-compose
  extract
  colored-man-pages
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# =========================================================
# SHELL OPTIONS
# =========================================================

setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_GLOB
setopt EXTENDED_HISTORY
setopt NO_BEEP
setopt COMPLETE_IN_WORD

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

# =========================================================
# COMPLETION
# =========================================================

mkdir -p "$HOME/.cache/zsh"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/.zcompcache"

# =========================================================
# BUILD / DOCKER
# =========================================================

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# =========================================================
# NODE / FNM / COREPACK
# =========================================================

export FNM_DIR="$DEV_STORAGE/fnm"
mkdir -p "$FNM_DIR"

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"

  # fallback to your pinned default when outside projects
  fnm use --silent-if-unchanged default >/dev/null 2>&1 || true

  # make sure corepack shims are available for the active node
  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
  fi
fi

# =========================================================
# BUM / BUN VERSION MANAGER HELPERS
# =========================================================

# Show current bun + bum status
bum-status() {
  echo "Bum binary: $(command -v bum 2>/dev/null || echo 'not found')"
  echo "Bun binary: $(command -v bun 2>/dev/null || echo 'not found')"
  echo "Bum version: $(bum --version 2>/dev/null || echo 'unknown')"
  echo "Bun version: $(bun --version 2>/dev/null || echo 'unknown')"
  echo

  if [ -f .bumrc ]; then
    echo ".bumrc: $(cat .bumrc)"
  else
    echo ".bumrc: not present"
  fi
}

# Short aliases
alias bi='bun install'
alias br='bun run'
alias bx='bunx'
alias bt='bun test'
alias bdev='bun run dev'
alias bbuild='bun run build'

# Use a Bun version
bmu() {
  if [ -z "$1" ]; then
    echo "Usage: bmu <version>"
    return 1
  fi

  bum use "$1"
  bun --version
}

# Write local project version to .bumrc and switch to it
bmset() {
  if [ -z "$1" ]; then
    echo "Usage: bmset <version>"
    return 1
  fi

  printf "%s\n" "$1" > .bumrc
  echo "Wrote .bumrc -> $1"
  bum use "$1"
}

# Use version from .bumrc explicitly
bmuse() {
  if [ ! -f .bumrc ]; then
    echo "No .bumrc found in current directory"
    return 1
  fi

  bum use
  bun --version
}

# Remove a locally installed Bun version
bmrm() {
  if [ -z "$1" ]; then
    echo "Usage: bmrm <version>"
    return 1
  fi

  bum remove "$1"
}

# Show available remote versions with optional grep filter
bmsearch() {
  if [ -n "$1" ]; then
    bum list-remote | grep -i "$1"
  else
    bum list-remote
  fi
}

# Auto-use .bumrc when entering a directory
bm-auto-use() {
  if [ -f .bumrc ]; then
    local target
    target="$(cat .bumrc 2>/dev/null)"

    if [ -n "$target" ]; then
      local current
      current="$(bun --version 2>/dev/null)"

      if [ "$current" != "$target" ]; then
        echo "Switching Bun version via .bumrc -> $target"
        bum use "$target" >/dev/null && bun --version
      fi
    fi
  fi
}

# zsh hook
if [ -n "$ZSH_VERSION" ]; then
  autoload -U add-zsh-hook 2>/dev/null
  add-zsh-hook chpwd bm-auto-use 2>/dev/null
fi

# bash hook
if [ -n "$BASH_VERSION" ]; then
  case ";$PROMPT_COMMAND;" in
    *";bm-auto-use;"*) ;;
    *)
      PROMPT_COMMAND="bm-auto-use${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
      ;;
  esac
fi

# =========================================================
# TOOL INIT
# =========================================================

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if [ -f "$HOME/.fzf.zsh" ]; then
  source "$HOME/.fzf.zsh"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# =========================================================
# BETTER COMMANDS
# =========================================================

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -lah --icons --group-directories-first"
  alias la="eza -a --icons --group-directories-first"
else
  alias ll="ls -lah"
  alias la="ls -la"
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat --style=plain"
fi

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# =========================================================
# VS CODE
# =========================================================

if command -v code-insiders >/dev/null 2>&1; then
  alias code="code-insiders"
fi

alias c="code"
alias c.="code ."

# =========================================================
# NAVIGATION
# =========================================================

alias ..="cd .."
alias ...="cd ../.."

cw()   { cd "$DEV_STORAGE"; }
cwr()  { cd "$DEV_STORAGE/repos"; }
cww()  { cd "$DEV_STORAGE/repos/work"; }
cwp()  { cd "$DEV_STORAGE/repos/personal"; }

# =========================================================
# REPO HELPERS
# =========================================================

_repo_select_from_base() {
  local base="$1"
  local query="${2:-}"
  local open_code="${3:-0}"
  local selected
  local -a matches

  [ -d "$base" ] || {
    echo "repo base not found: $base"
    return 1
  }

  if [ -n "$query" ]; then
    matches=("${(@f)$(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s#$base/##" | grep -i -- "$query" | sort)}")
  else
    matches=("${(@f)$(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s#$base/##" | sort)}")
  fi

  case "${#matches[@]}" in
    0)
      echo "no repo match found"
      return 1
      ;;
    1)
      selected="${matches[1]}"
      ;;
    *)
      if ! command -v fzf >/dev/null 2>&1; then
        echo "multiple matches found, but fzf is not installed"
        printf '%s\n' "${matches[@]}"
        return 1
      fi

      selected="$(
        printf '%s\n' "${matches[@]}" | \
          fzf \
            --height 50% \
            --layout=reverse \
            --border \
            --prompt="repo > " \
            --query="$query" \
            --preview 'eza -lah --icons --group-directories-first "'"$base"'"/{} 2>/dev/null || ls -lah "'"$base"'"/{}'
      )" || return 1
      ;;
  esac

  cd "$base/$selected" || return 1

  if [ "$open_code" = "1" ]; then
    code .
  fi
}

workrepo() {
  local query="${1:-}"
  _repo_select_from_base "$DEV_STORAGE/repos/work" "$query" 0
}

persrepo() {
  local query="${1:-}"
  _repo_select_from_base "$DEV_STORAGE/repos/personal" "$query" 0
}

mkworkrepo() {
  local name="$1"
  [ -n "$name" ] || { echo "usage: mkworkrepo <repo>"; return 1; }
  mkdir -p "$DEV_STORAGE/repos/work/$name" &&
    cd "$DEV_STORAGE/repos/work/$name" &&
    git init &&
    code .
}

mkpersrepo() {
  local name="$1"
  [ -n "$name" ] || { echo "usage: mkpersrepo <repo>"; return 1; }
  mkdir -p "$DEV_STORAGE/repos/personal/$name" &&
    cd "$DEV_STORAGE/repos/personal/$name" &&
    git init &&
    code .
}

reposfind() {
  find "$DEV_STORAGE/repos" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | \
    sed "s#$DEV_STORAGE/repos/##" | \
    sort
}

repo() {
  local query=""
  local open_code=0
  local selected
  local -a matches
  local base="$DEV_STORAGE/repos"

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  [ -d "$base" ] || {
    echo "repo base not found: $base"
    return 1
  }

  if [ -n "$query" ]; then
    matches=("${(@f)$(find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#$base/##" | grep -i -- "$query" | sort)}")
  else
    matches=("${(@f)$(find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#$base/##" | sort)}")
  fi

  case "${#matches[@]}" in
    0)
      echo "no repo match found"
      return 1
      ;;
    1)
      selected="${matches[1]}"
      ;;
    *)
      if ! command -v fzf >/dev/null 2>&1; then
        echo "multiple matches found, but fzf is not installed"
        printf '%s\n' "${matches[@]}"
        return 1
      fi

      selected="$(
        printf '%s\n' "${matches[@]}" | \
          fzf \
            --height 50% \
            --layout=reverse \
            --border \
            --prompt="repo > " \
            --query="$query" \
            --preview 'eza -lah --icons --group-directories-first "'"$base"'"/{} 2>/dev/null || ls -lah "'"$base"'"/{}'
      )" || return 1
      ;;
  esac

  cd "$base/$selected" || return 1

  if [ "$open_code" = "1" ]; then
    code .
  fi
}

repo-work() {
  local query=""
  local open_code=0

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  _repo_select_from_base "$DEV_STORAGE/repos/work" "$query" "$open_code"
}

repo-personal() {
  local query=""
  local open_code=0

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  _repo_select_from_base "$DEV_STORAGE/repos/personal" "$query" "$open_code"
}

repo-code() {
  repo --code "$@"
}

repo-root() {
  git rev-parse --show-toplevel 2>/dev/null
}

alias wr="workrepo"
alias prj="persrepo"
alias mkwr="mkworkrepo"
alias mkprj="mkpersrepo"
alias rls="reposfind"
alias rf="repo"
alias rfw="repo-work"
alias rfp="repo-personal"
alias rc="repo-code"

# =========================================================
# GIT
# =========================================================

alias gs="git status -sb"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit"
alias gp="git push"
alias gpl="git pull --rebase"

# =========================================================
# NODE / PNPM
# =========================================================

alias n="npm"
alias ni="pnpm install"
alias nr="pnpm run"
alias pr="pnpm run"
alias px="pnpm dlx"

# =========================================================
# NX
# =========================================================

alias nx="pnpm nx"
alias nxg="pnpm nx graph"
alias nxr="pnpm nx reset"

# =========================================================
# DOCKER
# =========================================================

alias d="docker"
alias dps="docker ps"
alias dc="docker compose"

# =========================================================
# UTILITIES
# =========================================================

alias cls="clear"
alias lg="lazygit"
alias zshreload="source ~/.zshrc"

# =========================================================
# DEV STORAGE UTILITIES
# =========================================================

devstorage-status() {
  echo "DEV_STORAGE:      $DEV_STORAGE"
  echo "DEV_STORAGE_MODE: $DEV_STORAGE_MODE"
}

# =========================================================
# OLLAMA
# =========================================================

ollama-refresh-env() {
  launchctl setenv OLLAMA_MODELS "$HOME/DevStorage/ai-models/ollama"
  launchctl setenv OLLAMA_HOST "127.0.0.1:11434"
  echo "OLLAMA_MODELS=$(launchctl getenv OLLAMA_MODELS)"
  echo "OLLAMA_HOST=$(launchctl getenv OLLAMA_HOST)"
}

ollama-restart() {
  osascript -e 'quit app "Ollama"' >/dev/null 2>&1 || true
  sleep 1

  if [ -x "$HOME/bin/devstorage-switch" ]; then
    "$HOME/bin/devstorage-switch" >/dev/null 2>&1
  fi

  mkdir -p "$HOME/DevStorage/ai-models/ollama"
  launchctl setenv OLLAMA_MODELS "$HOME/DevStorage/ai-models/ollama"
  launchctl setenv OLLAMA_HOST "127.0.0.1:11434"

  open -a Ollama
}

ollama-status() {
  echo "OLLAMA_MODELS: $(launchctl getenv OLLAMA_MODELS)"
  echo "OLLAMA_HOST:   $(launchctl getenv OLLAMA_HOST)"
  curl -fsS http://127.0.0.1:11434 >/dev/null && echo "Ollama API: up" || echo "Ollama API: down"
}

ollama-models() {
  curl -fsS http://127.0.0.1:11434/api/tags
}

ollama-logs() {
  cat ~/.ollama/logs/server.log
}

ollama-chat() {
  local model="${1:-gemma3}"
  ollama run "$model"
}

ollama-api-test() {
  local model="${1:-gemma3}"
  curl http://127.0.0.1:11434/api/generate -d "{
    \"model\": \"$model\",
    \"prompt\": \"Say hello in one short sentence.\"
  }"
}

ollama-stop() {
  pkill -f ollama >/dev/null 2>&1 || true
  osascript -e 'quit app "Ollama"' >/dev/null 2>&1 || true
}

ollama-start() {
  open -a Ollama
}

ollama-reload() {
  ollama-stop
  sleep 1
  ollama-restart
}

# =========================================================
# LLAMA.CPP
# =========================================================

llama-models-dir() {
  mkdir -p "$LLAMA_CPP_MODELS"
  echo "$LLAMA_CPP_MODELS"
}

llama-models() {
  mkdir -p "$LLAMA_CPP_MODELS"
  ls -lah "$LLAMA_CPP_MODELS"
}

llama-cli-local() {
  local model="$1"
  if [ $# -gt 0 ]; then
    shift
  fi

  if [ -z "$model" ]; then
    echo "Usage: llama-cli-local <model.gguf> [extra llama-cli args]"
    return 1
  fi

  mkdir -p "$LLAMA_CPP_MODELS"
  llama-cli -m "$LLAMA_CPP_MODELS/$model" "$@"
}

llama-server-local() {
  local model="$1"
  if [ $# -gt 0 ]; then
    shift
  fi

  if [ -z "$model" ]; then
    echo "Usage: llama-server-local <model.gguf> [extra llama-server args]"
    return 1
  fi

  mkdir -p "$LLAMA_CPP_MODELS"
  llama-server -m "$LLAMA_CPP_MODELS/$model" --port 8080 "$@"
}

llama-bench-local() {
  local model="$1"
  if [ $# -gt 0 ]; then
    shift
  fi

  if [ -z "$model" ]; then
    echo "Usage: llama-bench-local <model.gguf> [extra llama-bench args]"
    return 1
  fi

  mkdir -p "$LLAMA_CPP_MODELS"
  llama-bench -m "$LLAMA_CPP_MODELS/$model" "$@"
}

# =========================================================
# AUTO SSD HEAL
# =========================================================

autoload -Uz add-zsh-hook

devstorage-autoheal() {

  if ! builtin pwd >/dev/null 2>&1; then
    cd "$DEV_STORAGE" 2>/dev/null || cd "$HOME"
  fi
}

add-zsh-hook precmd devstorage-autoheal

# =========================================================
# WARNING IF SSD NOT MOUNTED
# =========================================================

if [[ -o interactive && "$DEV_STORAGE_MODE" = "local" ]]; then
  echo "⚠️ WorkSSD not mounted — using local fallback"
fi

# =========================================================
# LOCAL OVERRIDES
# =========================================================

if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

# bun completions
[ -s "/Users/acordeiro/.bun/_bun" ] && source "/Users/acordeiro/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias claude-mem='/Users/acordeiro/.bun/bin/bun "/Users/acordeiro/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# opencode
export PATH=/Users/acordeiro/.opencode/bin:$PATH

# =========================================================
# LLAMA.CPP SERVER HELPERS
# =========================================================

llama-start() {
  local model="${1:-$LLAMA_CPP_DEFAULT_MODEL}"
  if [ $# -gt 0 ]; then
    shift
  fi

  mkdir -p "$LLAMA_CPP_MODELS" "$LLAMA_CPP_LOGS"

  if [ ! -e "$LLAMA_CPP_MODELS/$model" ]; then
    echo "Model not found: $LLAMA_CPP_MODELS/$model"
    echo "Available models:"
    llama-models
    return 1
  fi

  llama-stop >/dev/null 2>&1 || true

  nohup llama-server \
    -m "$LLAMA_CPP_MODELS/$model" \
    --alias "$LLAMA_CPP_SERVER_ALIAS" \
    --host "$LLAMA_CPP_HOST" \
    --port "$LLAMA_CPP_PORT" \
    -ngl 999 \
    -fa on \
    "$@" > "$LLAMA_CPP_LOGS/server.log" 2>&1 &

  sleep 2
  llama-status
}

llama-stop() {
  pkill -f "(^|/)llama-server($| )" >/dev/null 2>&1 || true
}

llama-status() {
  echo "LLAMA_CPP_MODELS:        $LLAMA_CPP_MODELS"
  echo "LLAMA_CPP_DEFAULT_MODEL: $LLAMA_CPP_DEFAULT_MODEL"
  echo "LLAMA_CPP_LOGS:          $LLAMA_CPP_LOGS"
  echo "LLAMA_CPP_ENDPOINT:      http://$LLAMA_CPP_HOST:$LLAMA_CPP_PORT"
  curl -fsS "http://$LLAMA_CPP_HOST:$LLAMA_CPP_PORT/" >/dev/null && echo "llama.cpp API: up" || echo "llama.cpp API: down"
}

llama-logs() {
  cat "$LLAMA_CPP_LOGS/server.log"
}

llama-api-test() {
  curl -fsS "http://$LLAMA_CPP_HOST:$LLAMA_CPP_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\n      \"model\": \"$LLAMA_CPP_SERVER_ALIAS\",\n      \"messages\": [\n        {\"role\": \"user\", \"content\": \"Say hello in one short sentence.\"}\n      ]\n    }"
}


llama-api-test() {
  curl -fsS "http://$LLAMA_CPP_HOST:$LLAMA_CPP_PORT/v1/chat/completions"     -H "Content-Type: application/json"     -d '{"model":"'"$LLAMA_CPP_SERVER_ALIAS"'","messages":[{"role":"user","content":"Say hello in one short sentence."}]}'
}

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/acordeiro/.lmstudio/bin"
# End of LM Studio CLI section

