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
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-cli-local <relative-model-path> [extra llama-cli args]"
    return 1
  fi

  local model_path="$LLAMA_CPP_MODELS/$model"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    return 1
  fi

  llama-cli -m "$model_path" "$@"
}

llama-server-local() {
  local model="$1"
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-server-local <relative-model-path> [extra llama-server args]"
    return 1
  fi

  local model_path="$LLAMA_CPP_MODELS/$model"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    return 1
  fi

  llama-server \
    -m "$model_path" \
    --host "$LLAMA_CPP_HOST" \
    --port "$LLAMA_CPP_PORT" \
    "$@"
}

llama-bench-local() {
  local model="$1"
  shift || true

  if [ -z "$model" ]; then
    echo "Usage: llama-bench-local <relative-model-path> [extra llama-bench args]"
    return 1
  fi

  local model_path="$LLAMA_CPP_MODELS/$model"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    return 1
  fi

  llama-bench -m "$model_path" "$@"
}

llama-start() {
  local model="${1:-$LLAMA_CPP_DEFAULT_MODEL}"
  shift || true

  local model_path="$LLAMA_CPP_MODELS/$model"

  mkdir -p "$LLAMA_CPP_MODELS" "$LLAMA_CPP_CACHE" "$LLAMA_CPP_LOGS"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    echo "Available models:"
    llama-models
    return 1
  fi

  llama-stop >/dev/null 2>&1 || true

  nohup llama-server \
    -m "$model_path" \
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
  echo "LLAMA_CPP_SRC:           $LLAMA_CPP_SRC"
  echo "LLAMA_CPP_BIN:           $LLAMA_CPP_BIN"
  echo "LLAMA_CPP_MODELS:        $LLAMA_CPP_MODELS"
  echo "LLAMA_CPP_CACHE:         $LLAMA_CPP_CACHE"
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
    -d '{"model":"'"$LLAMA_CPP_SERVER_ALIAS"'","messages":[{"role":"user","content":"Say hello in one short sentence."}]}'
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
