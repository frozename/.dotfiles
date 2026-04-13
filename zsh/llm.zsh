# =========================================================
# LLM / DEV STORAGE
# =========================================================

devstorage-status() {
  echo "DEV_STORAGE:      $DEV_STORAGE"
  echo "DEV_STORAGE_MODE: $DEV_STORAGE_MODE"
}

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

_llama_endpoint() {
  printf 'http://%s:%s\n' "$LLAMA_CPP_HOST" "$LLAMA_CPP_PORT"
}

_llama_model_path() {
  local model="$1"
  printf '%s/%s\n' "$LLAMA_CPP_MODELS" "$model"
}

_llama_require_model() {
  local model="$1"
  local model_path

  if [ -z "$model" ]; then
    return 1
  fi

  model_path="$(_llama_model_path "$model")"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    return 1
  fi

  printf '%s\n' "$model_path"
}

_llama_print_content() {
  local response="$1"

  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$response" | jq -r '.choices[0].message.content // empty'
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "$response" | python3 -c 'import json, sys; data = json.load(sys.stdin); print(data.get("choices", [{}])[0].get("message", {}).get("content", ""))'
    return 0
  fi

  printf '%s\n' "$response"
}

_llama_escape_json() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"

  printf '%s\n' "$value"
}

llama-src() {
  cd "$LLAMA_CPP_SRC" || return 1
}

llama-models-dir() {
  mkdir -p "$LLAMA_CPP_MODELS"
  echo "$LLAMA_CPP_MODELS"
}

llama-models() {
  mkdir -p "$LLAMA_CPP_MODELS"
  find "$LLAMA_CPP_MODELS" -type f \( -iname '*.gguf' -o -iname '*.gguf-split*' \) | sort
}

llama-build() {
  cd "$LLAMA_CPP_SRC" || return 1
  cmake -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build --config Release -j
}

llama-rebuild() {
  cd "$LLAMA_CPP_SRC" || return 1
  rm -rf build
  cmake -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build --config Release -j
}

llama-update() {
  cd "$LLAMA_CPP_SRC" || return 1
  git pull --rebase
  llama-build
}

llama-cli-local() {
  local model="$1"
  local model_path
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-cli-local <relative-model-path> [extra llama-cli args]"
    return 1
  fi

  model_path="$(_llama_require_model "$model")" || return 1

  llama-cli -m "$model_path" "$@"
}

llama-server-local() {
  local model="$1"
  local model_path
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-server-local <relative-model-path> [extra llama-server args]"
    return 1
  fi

  model_path="$(_llama_require_model "$model")" || return 1

  llama-server \
    -m "$model_path" \
    --host "$LLAMA_CPP_HOST" \
    --port "$LLAMA_CPP_PORT" \
    "$@"
}

llama-bench-local() {
  local model="$1"
  local model_path
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-bench-local <relative-model-path> [extra llama-bench args]"
    return 1
  fi

  model_path="$(_llama_require_model "$model")" || return 1

  llama-bench -m "$model_path" "$@"
}

llama-start() {
  local model="${1:-$LLAMA_CPP_DEFAULT_MODEL}"
  local health_endpoint="$(_llama_endpoint)/health"
  local model_path
  local pid
  local http_code=""
  local attempt=0
  shift || true

  mkdir -p "$LLAMA_CPP_MODELS" "$LLAMA_CPP_CACHE" "$LLAMA_CPP_LOGS"
  model_path="$(_llama_require_model "$model")" || {
    echo "Available models:"
    llama-models
    return 1
  }

  llama-stop >/dev/null 2>&1 || true

  nohup llama-server \
    -m "$model_path" \
    --alias "$LLAMA_CPP_SERVER_ALIAS" \
    --host "$LLAMA_CPP_HOST" \
    --port "$LLAMA_CPP_PORT" \
    -ngl 999 \
    -fa on \
    "$@" > "$LLAMA_CPP_LOGS/server.log" 2>&1 &
  pid=$!

  while [ "$attempt" -lt 60 ]; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "llama.cpp exited early"
      tail -n 50 "$LLAMA_CPP_LOGS/server.log" 2>/dev/null
      return 1
    fi

    http_code="$(curl -fsS -o /dev/null -w "%{http_code}" "$health_endpoint" 2>/dev/null || true)"

    case "$http_code" in
      200)
        llama-status
        return 0
        ;;
      503)
        ;;
    esac

    attempt=$((attempt + 1))
    sleep 1
  done

  echo "llama.cpp readiness check timed out"
  tail -n 50 "$LLAMA_CPP_LOGS/server.log" 2>/dev/null
  return 1
}

llama-stop() {
  pkill -f "(^|/)llama-server($| )" >/dev/null 2>&1 || true
}

llama-status() {
  local endpoint="$(_llama_endpoint)"
  local health_endpoint="$endpoint/health"
  local http_code=""
  local state="down"

  mkdir -p "$LLAMA_CPP_MODELS" "$LLAMA_CPP_CACHE" "$LLAMA_CPP_LOGS"

  echo "LLAMA_CPP_SRC:           $LLAMA_CPP_SRC"
  echo "LLAMA_CPP_BIN:           $LLAMA_CPP_BIN"
  echo "LLAMA_CPP_ROOT:          $LLAMA_CPP_ROOT"
  echo "LLAMA_CPP_MODELS:        $LLAMA_CPP_MODELS"
  echo "LLAMA_CPP_CACHE:         $LLAMA_CPP_CACHE"
  echo "LLAMA_CACHE:             $LLAMA_CACHE"
  echo "LLAMA_CPP_DEFAULT_MODEL: $LLAMA_CPP_DEFAULT_MODEL"
  echo "LLAMA_CPP_SERVER_ALIAS:  $LLAMA_CPP_SERVER_ALIAS"
  echo "LLAMA_CPP_HOST:          $LLAMA_CPP_HOST"
  echo "LLAMA_CPP_PORT:          $LLAMA_CPP_PORT"
  echo "LLAMA_CPP_LOGS:          $LLAMA_CPP_LOGS"
  echo "LLAMA_CPP_ENDPOINT:      $endpoint"

  http_code="$(curl -fsS -o /dev/null -w "%{http_code}" "$health_endpoint" 2>/dev/null || true)"

  case "$http_code" in
    200)
      state="ready"
      ;;
    503)
      state="loading"
      ;;
  esac

  echo "llama.cpp API:           $state"
}

llama-logs() {
  cat "$LLAMA_CPP_LOGS/server.log"
}

llama-api-test() {
  curl -fsS "$(_llama_endpoint)/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"'"$LLAMA_CPP_SERVER_ALIAS"'","messages":[{"role":"user","content":"Say hello in one short sentence."}]}'
}

hf-login() {
  hf auth login
}

hf-search() {
  if [ -z "$1" ]; then
    echo "Usage: hf-search <query>"
    return 1
  fi

  hf models ls --search "$1"
}

llama-pull() {
  local repo="$1"
  local target="${2:-}"

  if [ -z "$repo" ]; then
    echo "Usage: llama-pull <hf-repo> [target-dir]"
    return 1
  fi

  if [ -z "$target" ]; then
    target="$LLAMA_CPP_MODELS/${repo##*/}"
  fi

  mkdir -p "$target"
  hf download "$repo" --local-dir "$target"
}

llama-pull-file() {
  local repo="$1"
  local file="$2"
  local target

  if [ -z "$repo" ] || [ -z "$file" ]; then
    echo "Usage: llama-pull-file <hf-repo> <filename.gguf>"
    return 1
  fi

  target="$LLAMA_CPP_MODELS/${repo##*/}"
  mkdir -p "$target"
  hf download "$repo" "$file" --local-dir "$target"
}

llama-list() {
  mkdir -p "$LLAMA_CPP_MODELS"
  find "$LLAMA_CPP_MODELS" -type f \( -iname '*.gguf' -o -iname '*.gguf-split*' \) \
    ! -iname 'mmproj*.gguf' \
    ! -iname '*mmproj*' \
    ! -iname '*vision*' \
    ! -iname '*proj*' | sort
}

llama-run() {
  llama-start "$@"
}

llama-pick() {
  local selected

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is required for llama-pick"
    return 1
  fi

  selected="$(llama-list | sed "s#^$LLAMA_CPP_MODELS/##" | fzf --height 50% --layout=reverse --border --prompt='llama model > ')" || return 1
  [ -n "$selected" ] || return 1
  llama-start "$selected"
}

llama-chat() {
  local prompt="${*:-Say hello in one short sentence.}"
  local escaped_prompt
  local response

  escaped_prompt="$(_llama_escape_json "$prompt")"
  response="$(
    curl -fsS "$(_llama_endpoint)/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d '{"model":"'"$LLAMA_CPP_SERVER_ALIAS"'","messages":[{"role":"user","content":"'"$escaped_prompt"'"}]}'
  )" || return 1

  _llama_print_content "$response"
}

llama-clean() {
  mkdir -p "$LLAMA_CPP_CACHE"

  if [ -z "$LLAMA_CPP_CACHE" ] || [ "$LLAMA_CPP_CACHE" = "/" ]; then
    echo "Refusing to clean invalid cache path"
    return 1
  fi

  find "$LLAMA_CPP_CACHE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

run-gemma4-e4b() {
  llama-start "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" \
    --mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF/mmproj-BF16.gguf" \
    --ctx-size 32768 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs '{"enable_thinking":false}'
}

run-gemma4-26b() {
  llama-start "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" \
    --mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF/mmproj-BF16.gguf" \
    --ctx-size 32768 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs '{"enable_thinking":false}'
}

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

autoload -Uz add-zsh-hook

devstorage-autoheal() {
  if ! builtin pwd >/dev/null 2>&1; then
    cd "$DEV_STORAGE" 2>/dev/null || cd "$HOME"
  fi
}

add-zsh-hook precmd devstorage-autoheal

if [[ -o interactive && "$DEV_STORAGE_MODE" = "local" ]]; then
  echo "⚠️ WorkSSD not mounted — using local fallback"
fi
