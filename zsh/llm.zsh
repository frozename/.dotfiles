# =========================================================
# LLM / DEV STORAGE
# =========================================================

devstorage-status() {
  echo "WORKSSD:          $WORKSSD"
  echo "DEV_STORAGE:      $DEV_STORAGE"
  echo "DEV_STORAGE_MODE: $DEV_STORAGE_MODE"
  if [ -n "$DEV_STORAGE_REPAIR_BACKUP" ]; then
    echo "DEV_STORAGE_BACKUP: $DEV_STORAGE_REPAIR_BACKUP"
  fi
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

  if typeset -f devstorage_switch >/dev/null 2>&1; then
    devstorage_switch >/dev/null 2>&1
  elif [ -x "$HOME/bin/devstorage-switch" ]; then
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

  if [ ! -f "$model_path" ]; then
    echo "Model file not found: $model_path"
    return 1
  fi

  printf '%s\n' "$model_path"
}

_llama_list_runnable_models() {
  mkdir -p "$LLAMA_CPP_MODELS"

  find "$LLAMA_CPP_MODELS" -type f -iname '*.gguf' \
    ! -iname 'mmproj*.gguf' \
    ! -iname '*mmproj*' \
    ! -iname '*vision*' \
    ! -iname '*proj*' \
    | sort
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
  _llama_list_runnable_models
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
  if [ $# -gt 0 ]; then
    shift
  fi

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
  if [ $# -gt 0 ]; then
    shift
  fi

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
  if [ $# -gt 0 ]; then
    shift
  fi

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
  local timeout_seconds=60
  if [ $# -gt 0 ]; then
    shift
  fi

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

  while [ "$attempt" -lt "$timeout_seconds" ]; do
    http_code="$(curl -fsS -o /dev/null -w "%{http_code}" "$health_endpoint" 2>/dev/null || true)"

    case "$http_code" in
      200)
        llama-status
        return 0
        ;;
      503)
        ;;
      *)
        if ! kill -0 "$pid" >/dev/null 2>&1; then
          echo "llama.cpp exited before becoming ready"
          tail -n 50 "$LLAMA_CPP_LOGS/server.log" 2>/dev/null
          return 1
        fi
        ;;
    esac

    attempt=$((attempt + 1))
    sleep 1
  done

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    echo "llama.cpp exited before becoming ready"
    tail -n 50 "$LLAMA_CPP_LOGS/server.log" 2>/dev/null
    return 1
  fi

  echo "llama.cpp readiness check timed out after ${timeout_seconds}s"
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
  _llama_list_runnable_models
}

llama-run() {
  llama-start "$@"
}

llama-pick() {
  local models
  local selected

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is required for llama-pick"
    return 1
  fi

  models="$(llama-list)"
  if [ -z "$models" ]; then
    echo "No runnable GGUF models found under $LLAMA_CPP_MODELS"
    return 1
  fi

  selected="$(printf '%s\n' "$models" | sed "s#^$LLAMA_CPP_MODELS/##" | fzf --height 50% --layout=reverse --border --prompt='llama model > ')" || return 1
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
  local model_dir="$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF"
  local model=""
  local mmproj=""

  for candidate in \
    "gemma-4-E4B-it-Q8_0.gguf" \
    "gemma-4-E4B-it-UD-Q5_K_XL.gguf" \
    "gemma-4-E4B-it-UD-Q4_K_XL.gguf" \
    "gemma-4-E4B-it-Q6_K.gguf" \
    "gemma-4-E4B-it-Q5_K_M.gguf" \
    "gemma-4-E4B-it-Q4_K_M.gguf"
  do
    if [ -f "$model_dir/$candidate" ]; then
      model="gemma-4-E4B-it-GGUF/$candidate"
      break
    fi
  done

  if [ -z "$model" ]; then
    echo "No Gemma 4 E4B model found under $model_dir"
    echo "Try: gemma4-e4b-pull q8"
    return 1
  fi

  for candidate in "mmproj-BF16.gguf" "mmproj-F16.gguf"; do
    if [ -f "$model_dir/$candidate" ]; then
      mmproj="$model_dir/$candidate"
      break
    fi
  done

  if [ -z "$mmproj" ]; then
    echo "No Gemma 4 E4B mmproj file found under $model_dir"
    echo "Try: gemma4-e4b-pull q8"
    return 1
  fi

  llama-start "$model" \
    --mmproj "$mmproj" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs '{"enable_thinking":false}'
}

_llama_find_mmproj() {
  local model_dir="$1"

  for candidate in "mmproj-BF16.gguf" "mmproj-F16.gguf"; do
    if [ -f "$model_dir/$candidate" ]; then
      printf '%s/%s\n' "$model_dir" "$candidate"
      return 0
    fi
  done

  return 1
}

_llama_recommended_model_for_profile() {
  local profile="$1"
  local model=""

  case "$profile" in
    mac-mini-16g|mini|16g)
      for model in \
        "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" \
        "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf" \
        "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      do
        if [ -f "$LLAMA_CPP_MODELS/$model" ]; then
          printf '%s\n' "$model"
          return 0
        fi
      done

      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    balanced|mid)
      for model in \
        "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" \
        "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf" \
        "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      do
        if [ -f "$LLAMA_CPP_MODELS/$model" ]; then
          printf '%s\n' "$model"
          return 0
        fi
      done

      printf '%s\n' "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    *)
      for model in \
        "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf" \
        "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" \
        "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      do
        if [ -f "$LLAMA_CPP_MODELS/$model" ]; then
          printf '%s\n' "$model"
          return 0
        fi
      done

      printf '%s\n' "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
  esac
}

_llama_switch_default_model() {
  local model="$1"
  local model_path

  if [ -z "$model" ]; then
    echo "Usage: _llama_switch_default_model <relative-model-path>"
    return 1
  fi

  model_path="$LLAMA_CPP_MODELS/$model"

  if [ ! -e "$model_path" ]; then
    echo "Model not found: $model_path"
    return 1
  fi

  export LLAMA_CPP_DEFAULT_MODEL="$model"
  echo "LLAMA_CPP_DEFAULT_MODEL -> $LLAMA_CPP_DEFAULT_MODEL"
}

llama-profile() {
  local profile="${1:-current}"
  local model=""

  case "$profile" in
    current)
      echo "LLAMA_CPP_MACHINE_PROFILE=$LLAMA_CPP_MACHINE_PROFILE"
      echo "LLAMA_CPP_GEMMA_CTX_SIZE=$LLAMA_CPP_GEMMA_CTX_SIZE"
      echo "LLAMA_CPP_DEFAULT_MODEL=$LLAMA_CPP_DEFAULT_MODEL"
      return 0
      ;;
    mac-mini-16g|mini|16g)
      export LLAMA_CPP_MACHINE_PROFILE="mac-mini-16g"
      export LLAMA_CPP_GEMMA_CTX_SIZE="16384"
      ;;
    balanced|mid)
      export LLAMA_CPP_MACHINE_PROFILE="balanced"
      export LLAMA_CPP_GEMMA_CTX_SIZE="24576"
      ;;
    macbook-pro-48g|macbook-pro|mbp|laptop|desktop-48g|desktop|48g|best)
      export LLAMA_CPP_MACHINE_PROFILE="macbook-pro-48g"
      export LLAMA_CPP_GEMMA_CTX_SIZE="32768"
      ;;
    *)
      echo "Usage: llama-profile {mini|balanced|macbook-pro|current}"
      return 1
      ;;
  esac

  model="$(_llama_recommended_model_for_profile "$LLAMA_CPP_MACHINE_PROFILE")"
  export LLAMA_CPP_DEFAULT_MODEL="$model"

  echo "LLAMA_CPP_MACHINE_PROFILE=$LLAMA_CPP_MACHINE_PROFILE"
  echo "LLAMA_CPP_GEMMA_CTX_SIZE=$LLAMA_CPP_GEMMA_CTX_SIZE"
  echo "LLAMA_CPP_DEFAULT_MODEL=$LLAMA_CPP_DEFAULT_MODEL"
}

llama-profile-mini() {
  llama-profile mini
}

llama-profile-macbook-pro() {
  llama-profile macbook-pro
}

llama-profile-desktop() {
  llama-profile macbook-pro
}

llama-use() {
  case "$1" in
    best|quality|31b|gemma4-31b|gemma-4-31b)
      _llama_switch_default_model "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
    balanced|daily|26b|gemma4-26b|gemma-4-26b)
      _llama_switch_default_model "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    fast|small|e4b|gemma4-e4b|gemma-4-e4b)
      _llama_switch_default_model "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    current|"")
      echo "LLAMA_CPP_DEFAULT_MODEL=$LLAMA_CPP_DEFAULT_MODEL"
      ;;
    *)
      echo "Usage: llama-use {best|balanced|fast|31b|26b|e4b|current}"
      return 1
      ;;
  esac
}

llama-use-best() {
  llama-use best
}

llama-use-balanced() {
  llama-use balanced
}

llama-use-fast() {
  llama-use fast
}

llama-use-e4b() {
  llama-use e4b
}

llama-use-26b() {
  llama-use 26b
}

llama-use-31b() {
  llama-use 31b
}

run-gemma4-26b() {
  local mmproj

  mmproj="$(_llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF")" || {
    echo "No Gemma 4 26B mmproj file found under $LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF"
    echo "Try: gemma4-26b-pull q4"
    return 1
  }

  llama-start "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf" \
    --mmproj "$mmproj" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs '{"enable_thinking":false}'
}

llama-pull-gemma4-26b() {
  local target="$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF"
  local quant="${1:-q4}"
  local model_file=""

  case "$quant" in
    q4|4bit|recommended|default|balanced)
      model_file="gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    q5)
      model_file="gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf"
      ;;
    q6)
      model_file="gemma-4-26B-A4B-it-UD-Q6_K_XL.gguf"
      ;;
    q8|8bit)
      model_file="gemma-4-26B-A4B-it-Q8_0.gguf"
      ;;
    *.gguf)
      model_file="$quant"
      ;;
    *)
      echo "Usage: llama-pull-gemma4-26b [q4|q5|q6|q8|<filename.gguf>]"
      return 1
      ;;
  esac

  mkdir -p "$target"
  hf download unsloth/gemma-4-26B-A4B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
}

llama-pull-gemma4-e4b() {
  local target="$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF"
  local quant="${1:-q8}"
  local model_file=""

  case "$quant" in
    q8|8bit|recommended|default)
      model_file="gemma-4-E4B-it-Q8_0.gguf"
      ;;
    q4|4bit|balanced)
      model_file="gemma-4-E4B-it-UD-Q4_K_XL.gguf"
      ;;
    q5)
      model_file="gemma-4-E4B-it-UD-Q5_K_XL.gguf"
      ;;
    q6)
      model_file="gemma-4-E4B-it-UD-Q6_K_XL.gguf"
      ;;
    q4km)
      model_file="gemma-4-E4B-it-Q4_K_M.gguf"
      ;;
    q5km)
      model_file="gemma-4-E4B-it-Q5_K_M.gguf"
      ;;
    *.gguf)
      model_file="$quant"
      ;;
    *)
      echo "Usage: llama-pull-gemma4-e4b [q8|q4|q5|q6|q4km|q5km|<filename.gguf>]"
      return 1
      ;;
  esac

  mkdir -p "$target"
  hf download unsloth/gemma-4-E4B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
}

llama-pull-gemma4-31b() {
  local target="$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF"
  local quant="${1:-q4}"
  local model_file=""

  case "$quant" in
    q4|4bit|recommended|default|best)
      model_file="gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
    q5)
      model_file="gemma-4-31B-it-UD-Q5_K_XL.gguf"
      ;;
    q6)
      model_file="gemma-4-31B-it-UD-Q6_K_XL.gguf"
      ;;
    q8|8bit)
      model_file="gemma-4-31B-it-Q8_0.gguf"
      ;;
    *.gguf)
      model_file="$quant"
      ;;
    *)
      echo "Usage: llama-pull-gemma4-31b [q4|q5|q6|q8|<filename.gguf>]"
      return 1
      ;;
  esac

  mkdir -p "$target"
  hf download unsloth/gemma-4-31B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
}

llama-pull-qwen35-27b-q5() {
  local target="$LLAMA_CPP_MODELS/Qwen3.5-27B-GGUF"

  mkdir -p "$target"
  hf download unsloth/Qwen3.5-27B-GGUF \
    Qwen3.5-27B-UD-Q5_K_XL.gguf \
    --local-dir "$target"
}

run-qwen35-27b() {
  llama-start "Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp 0.7 \
    --top-p 0.8
}

run-gemma4-31b() {
  local mmproj

  mmproj="$(_llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF")" || {
    echo "No Gemma 4 31B mmproj file found under $LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF"
    echo "Try: gemma4-31b-pull q4"
    return 1
  }

  llama-start "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf" \
    --mmproj "$mmproj" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs '{"enable_thinking":false}'
}

alias qwen27='run-qwen35-27b'
alias gemma4-best='run-gemma4-31b'
alias gemma4-balanced='run-gemma4-26b'
alias gemma4-fast='run-gemma4-e4b'
alias gemma4-mini='run-gemma4-e4b'
alias gemma4-profile-mini='llama-profile mini'
alias gemma4-profile-macbook-pro='llama-profile macbook-pro'
alias gemma4-profile-desktop='llama-profile macbook-pro'
alias gemma4-best-pull='llama-pull-gemma4-31b'
alias gemma4-balanced-pull='llama-pull-gemma4-26b'
alias gemma4-fast-pull='llama-pull-gemma4-e4b'
alias gemma4-mini-pull='llama-pull-gemma4-e4b q8'
alias gemma4-31b-pull='llama-pull-gemma4-31b'
alias gemma4-26b-pull='llama-pull-gemma4-26b'
alias gemma4-e4b-pull='llama-pull-gemma4-e4b'
alias qwen27-pull='llama-pull-qwen35-27b-q5'

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

autoload -Uz add-zsh-hook

devstorage-autoheal() {
  if ! builtin pwd >/dev/null 2>&1; then
    cd "$DEV_STORAGE" 2>/dev/null || cd "$HOME"
  fi
}

add-zsh-hook precmd devstorage-autoheal

if [[ -o interactive ]]; then
  if [[ -n "$DEV_STORAGE_REPAIR_BACKUP" ]]; then
    echo "ℹ️ Archived legacy DevStorage to $DEV_STORAGE_REPAIR_BACKUP and switched back to WorkSSD"
  fi

  if [[ "$DEV_STORAGE_MODE" = "local" ]]; then
    if [[ -d "$WORKSSD" ]]; then
      echo "⚠️ WorkSSD is mounted, but DevStorage is still using local storage"
    else
      echo "⚠️ WorkSSD not mounted — using local fallback"
    fi
  fi
fi
