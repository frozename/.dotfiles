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

_llama_start_gemma4_model() {
  local rel="$1"
  local model_dir="$2"
  local label="$3"
  local mmproj

  _local_ai_ensure_model_assets "$rel" || return 1

  mmproj="$(_llama_find_mmproj "$LLAMA_CPP_MODELS/$model_dir")" || {
    echo "No $label mmproj file found under $LLAMA_CPP_MODELS/$model_dir"
    return 1
  }

  llama-start "$rel" \
    --mmproj "$mmproj" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --chat-template-kwargs "$(_local_ai_chat_template_kwargs)"
}

_llama_default_e4b_model() {
  local model_dir="$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF"
  local candidate

  for candidate in \
    "gemma-4-E4B-it-Q8_0.gguf" \
    "gemma-4-E4B-it-UD-Q5_K_XL.gguf" \
    "gemma-4-E4B-it-UD-Q4_K_XL.gguf" \
    "gemma-4-E4B-it-UD-Q6_K_XL.gguf" \
    "gemma-4-E4B-it-Q5_K_M.gguf" \
    "gemma-4-E4B-it-Q4_K_M.gguf"
  do
    if [ -f "$model_dir/$candidate" ]; then
      printf '%s\n' "gemma-4-E4B-it-GGUF/$candidate"
      return 0
    fi
  done

  printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
}

run-gemma4-e4b() {
  local model="${1:-$(_llama_default_e4b_model)}"

  _llama_start_gemma4_model "$model" "gemma-4-E4B-it-GGUF" "Gemma 4 E4B"
}

_llama_find_mmproj() {
  local model_dir="$1"
  local candidate

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
  LOCAL_AI_SOURCE_MODEL="$model"

  if typeset -f _local_ai_sync_env >/dev/null 2>&1; then
    _local_ai_sync_env >/dev/null 2>&1 || true
  fi

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
  LOCAL_AI_SOURCE_MODEL="$model"

  if typeset -f _local_ai_sync_env >/dev/null 2>&1; then
    _local_ai_sync_env >/dev/null 2>&1 || true
  fi

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

llama-switch() {
  local target="${1:-current}"
  local rel=""

  case "$target" in
    current)
      _local_ai_run_llama_cpp_source "$(_local_ai_source_model)"
      ;;
    best|quality|vision|image|balanced|daily|fast|small|31b|gemma4-31b|gemma-4-31b|26b|gemma4-26b|gemma-4-26b|e4b|gemma4-e4b|gemma-4-e4b|qwen|qwen27|qwen3.5-27b|*.gguf|*/*)
      rel="$(_local_ai_resolve_model_target "$target")" || return 1
      if _local_ai_is_named_preset "$target"; then
        _local_ai_ensure_model_assets "$rel" || return 1
      fi
      _llama_switch_default_model "$rel" || return 1
      _local_ai_run_llama_cpp_source "$rel"
      ;;
    *)
      echo "Usage: llama-switch {best|vision|balanced|fast|31b|26b|e4b|qwen27|current|<relative-model-path>}"
      return 1
      ;;
  esac
}

llama-switch-best() {
  llama-switch best
}

llama-switch-balanced() {
  llama-switch balanced
}

llama-switch-fast() {
  llama-switch fast
}

llama-switch-vision() {
  llama-switch vision
}

llama-use() {
  local target="$1"
  local apply_now="$2"
  local rel=""

  case "$apply_now" in
    now|run|switch)
      llama-switch "$target"
      return $?
      ;;
  esac

  case "$target" in
    best|quality|vision|image|balanced|daily|fast|small|31b|gemma4-31b|gemma-4-31b|26b|gemma4-26b|gemma-4-26b|e4b|gemma4-e4b|gemma-4-e4b|qwen|qwen27|qwen3.5-27b)
      rel="$(_local_ai_resolve_model_target "$target")" || return 1
      _llama_switch_default_model "$rel"
      ;;
    current|"")
      echo "LLAMA_CPP_DEFAULT_MODEL=$LLAMA_CPP_DEFAULT_MODEL"
      ;;
    *)
      echo "Usage: llama-use {best|vision|balanced|fast|31b|26b|e4b|qwen27|current}"
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
  local model="${1:-gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf}"

  _llama_start_gemma4_model "$model" "gemma-4-26B-A4B-it-GGUF" "Gemma 4 26B"
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

llama-pull-gemma4-26b-mmproj() {
  local target="$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF"

  mkdir -p "$target"
  hf download unsloth/gemma-4-26B-A4B-it-GGUF \
    mmproj-BF16.gguf \
    --local-dir "$target"
}

llama-pull-gemma4-31b-mmproj() {
  local target="$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF"

  mkdir -p "$target"
  hf download unsloth/gemma-4-31B-it-GGUF \
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
  local model="${1:-Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf}"
  local temp="0.7"
  local top_p="0.8"

  _local_ai_ensure_model_assets "$model" || return 1

  if _local_ai_thinking_enabled; then
    temp="1.0"
    top_p="0.95"
  fi

  llama-start "$model" \
    --ctx-size "$LLAMA_CPP_GEMMA_CTX_SIZE" \
    --temp "$temp" \
    --top-p "$top_p" \
    --top-k 20 \
    --presence-penalty 1.5 \
    --chat-template-kwargs "$(_local_ai_chat_template_kwargs)"
}

run-gemma4-31b() {
  local model="${1:-gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf}"

  _llama_start_gemma4_model "$model" "gemma-4-31B-it-GGUF" "Gemma 4 31B"
}

_local_ai_ensure_runtime_dir() {
  mkdir -p "$LOCAL_AI_RUNTIME_DIR"
}

_local_ai_validation_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/lmstudio-validation.tsv"
}

_local_ai_source_model() {
  printf '%s\n' "${LOCAL_AI_SOURCE_MODEL:-$LLAMA_CPP_DEFAULT_MODEL}"
}

_local_ai_thinking_enabled() {
  case "${LOCAL_AI_ENABLE_THINKING:-false}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_local_ai_chat_template_kwargs() {
  if _local_ai_thinking_enabled; then
    printf '%s\n' '{"enable_thinking":true}'
  else
    printf '%s\n' '{"enable_thinking":false}'
  fi
}

llama-thinking() {
  local mode="${1:-current}"

  case "$mode" in
    on|enable|enabled|true|thinking)
      export LOCAL_AI_ENABLE_THINKING="true"
      ;;
    off|disable|disabled|false|instruct|non-thinking|nonthinking)
      export LOCAL_AI_ENABLE_THINKING="false"
      ;;
    current|"")
      ;;
    *)
      echo "Usage: llama-thinking {on|off|current}"
      return 1
      ;;
  esac

  echo "LOCAL_AI_ENABLE_THINKING=$LOCAL_AI_ENABLE_THINKING"
  echo "LLAMA_CHAT_TEMPLATE_KWARGS=$(_local_ai_chat_template_kwargs)"
}

_local_ai_profile_name() {
  local profile="${1:-$LLAMA_CPP_MACHINE_PROFILE}"

  case "$profile" in
    mac-mini-16g|mini|16g)
      printf '%s\n' "mac-mini-16g"
      ;;
    balanced|mid)
      printf '%s\n' "balanced"
      ;;
    macbook-pro-48g|macbook-pro|mbp|laptop|desktop-48g|desktop|48g|best)
      printf '%s\n' "macbook-pro-48g"
      ;;
    *)
      printf '%s\n' "$profile"
      ;;
  esac
}

_local_ai_profile_preset_override() {
  local profile="$(_local_ai_profile_name "$1")"
  local preset="$2"
  local profile_key="${profile//-/_}"
  local preset_key="$preset"
  local var_name="LOCAL_AI_PRESET_${profile_key}_${preset_key}_MODEL"

  profile_key="${(U)profile_key}"
  preset_key="${(U)preset_key}"
  var_name="LOCAL_AI_PRESET_${profile_key}_${preset_key}_MODEL"

  printf '%s\n' "${(P)var_name}"
}

_local_ai_profile_preset_model() {
  local profile="$(_local_ai_profile_name "$1")"
  local preset="$2"
  local override="$(_local_ai_profile_preset_override "$profile" "$preset")"

  if [ -n "$override" ]; then
    printf '%s\n' "$override"
    return 0
  fi

  case "$profile:$preset" in
    mac-mini-16g:best)
      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    mac-mini-16g:vision)
      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    mac-mini-16g:balanced|mac-mini-16g:fast)
      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
      ;;
    *:best)
      printf '%s\n' "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
    *:balanced)
      printf '%s\n' "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    *:vision)
      printf '%s\n' "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    *:fast)
      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    *)
      echo "Unknown preset mapping for profile '$profile': $preset"
      return 1
      ;;
  esac
}

_local_ai_is_named_preset() {
  case "$1" in
    best|quality|vision|image|31b|gemma4-31b|gemma-4-31b|balanced|daily|26b|gemma4-26b|gemma-4-26b|fast|small|e4b|gemma4-e4b|gemma-4-e4b|qwen|qwen27|qwen3.5-27b)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_local_ai_list_importable_models() {
  mkdir -p "$LLAMA_CPP_MODELS"

  find "$LLAMA_CPP_MODELS" -type f -iname '*.gguf' \
    ! -iname 'mmproj*.gguf' \
    ! -iname '*mmproj*' \
    ! -iname '*proj*' \
    | sort
}

_local_ai_model_has_mmproj() {
  local rel="$1"
  local model_dir="$LLAMA_CPP_MODELS/${rel%/*}"
  local candidate

  for candidate in "$model_dir"/mmproj*.gguf "$model_dir"/*mmproj*.gguf; do
    if [ -f "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

_local_ai_lmstudio_model_key() {
  local rel="$1"
  local repo="${rel%%/*}"

  printf 'local/%s\n' "$repo"
}

_local_ai_get_validation_status() {
  local rel="$1"
  local file="$(_local_ai_validation_file)"

  if [ ! -f "$file" ]; then
    return 1
  fi

  awk -F '\t' -v rel="$rel" '$1 == rel { print $2 }' "$file" | tail -n 1
}

_local_ai_set_validation_status() {
  local rel="$1"
  local status="$2"
  local note="$3"
  local file="$(_local_ai_validation_file)"
  local tmp

  _local_ai_ensure_runtime_dir
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  tmp="$(mktemp "${TMPDIR:-/tmp}/local-ai-validation.XXXXXX")" || return 1

  if [ -f "$file" ]; then
    awk -F '\t' -v rel="$rel" '$1 != rel { print $0 }' "$file" > "$tmp"
  fi

  printf '%s\t%s\t%s\n' "$rel" "$status" "$note" >> "$tmp"
  mv "$tmp" "$file"
}

_local_ai_resolve_model_target() {
  local target="${1:-current}"

  case "$target" in
    current|"")
      _local_ai_source_model
      ;;
    best|quality)
      _local_ai_profile_preset_model "$LLAMA_CPP_MACHINE_PROFILE" "best"
      ;;
    vision|image)
      _local_ai_profile_preset_model "$LLAMA_CPP_MACHINE_PROFILE" "vision"
      ;;
    balanced|daily)
      _local_ai_profile_preset_model "$LLAMA_CPP_MACHINE_PROFILE" "balanced"
      ;;
    fast|small)
      _local_ai_profile_preset_model "$LLAMA_CPP_MACHINE_PROFILE" "fast"
      ;;
    31b|gemma4-31b|gemma-4-31b)
      printf '%s\n' "gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
    26b|gemma4-26b|gemma-4-26b)
      printf '%s\n' "gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    e4b|gemma4-e4b|gemma-4-e4b)
      printf '%s\n' "gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf"
      ;;
    qwen|qwen27|qwen3.5-27b)
      printf '%s\n' "Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf"
      ;;
    *.gguf|*/*)
      printf '%s\n' "$target"
      ;;
    *)
      echo "Unknown model target: $target"
      return 1
      ;;
  esac
}

_local_ai_ensure_model_assets() {
  local rel="$1"

  case "$rel" in
    gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 31B Q4 model..."
        llama-pull-gemma4-31b q4 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 31B mmproj..."
        llama-pull-gemma4-31b-mmproj || return 1
      fi
      ;;
    gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q5_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 31B Q5 model..."
        llama-pull-gemma4-31b q5 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 31B mmproj..."
        llama-pull-gemma4-31b-mmproj || return 1
      fi
      ;;
    gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q6_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 31B Q6 model..."
        llama-pull-gemma4-31b q6 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 31B mmproj..."
        llama-pull-gemma4-31b-mmproj || return 1
      fi
      ;;
    gemma-4-31B-it-GGUF/gemma-4-31B-it-Q8_0.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 31B Q8 model..."
        llama-pull-gemma4-31b q8 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 31B mmproj..."
        llama-pull-gemma4-31b-mmproj || return 1
      fi
      ;;
    gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 26B Q4 model..."
        llama-pull-gemma4-26b q4 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 26B mmproj..."
        llama-pull-gemma4-26b-mmproj || return 1
      fi
      ;;
    gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 26B Q5 model..."
        llama-pull-gemma4-26b q5 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 26B mmproj..."
        llama-pull-gemma4-26b-mmproj || return 1
      fi
      ;;
    gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q6_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 26B Q6 model..."
        llama-pull-gemma4-26b q6 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 26B mmproj..."
        llama-pull-gemma4-26b-mmproj || return 1
      fi
      ;;
    gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-Q8_0.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 26B Q8 model..."
        llama-pull-gemma4-26b q8 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 26B mmproj..."
        llama-pull-gemma4-26b-mmproj || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q8 model..."
        llama-pull-gemma4-e4b q8 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q8 || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q4 model..."
        llama-pull-gemma4-e4b q4 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q4 || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q5_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q5 model..."
        llama-pull-gemma4-e4b q5 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q5 || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q6_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q6 model..."
        llama-pull-gemma4-e4b q6 || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q6 || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q4_K_M.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q4_K_M model..."
        llama-pull-gemma4-e4b q4km || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q4km || return 1
      fi
      ;;
    gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q5_K_M.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Gemma 4 E4B Q5_K_M model..."
        llama-pull-gemma4-e4b q5km || return 1
      fi

      if ! _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1; then
        echo "Pulling missing Gemma 4 E4B mmproj..."
        llama-pull-gemma4-e4b q5km || return 1
      fi
      ;;
    Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Pulling missing Qwen 3.5 27B model..."
        llama-pull-qwen35-27b-q5 || return 1
      fi
      ;;
    *)
      if [ ! -f "$LLAMA_CPP_MODELS/$rel" ]; then
        echo "Model not found: $LLAMA_CPP_MODELS/$rel"
        return 1
      fi
      ;;
  esac
}

_local_ai_llama_cpp_model_runnable() {
  local rel="$1"

  case "$rel" in
    gemma-4-31B-it-GGUF/*)
      [ -f "$LLAMA_CPP_MODELS/$rel" ] || return 1
      _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF" >/dev/null 2>&1
      ;;
    gemma-4-26B-A4B-it-GGUF/*)
      [ -f "$LLAMA_CPP_MODELS/$rel" ] || return 1
      _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-26B-A4B-it-GGUF" >/dev/null 2>&1
      ;;
    gemma-4-E4B-it-GGUF/*)
      [ -f "$LLAMA_CPP_MODELS/$rel" ] || return 1
      _llama_find_mmproj "$LLAMA_CPP_MODELS/gemma-4-E4B-it-GGUF" >/dev/null 2>&1
      ;;
    *)
      [ -f "$LLAMA_CPP_MODELS/$rel" ]
      ;;
  esac
}

_local_ai_resolve_llama_cpp_target() {
  local target="${1:-current}"
  local requested=""
  local primary=""
  local candidates=""
  local candidate=""

  case "$target" in
    current|"")
      requested="$(_local_ai_source_model)"
      if _local_ai_llama_cpp_model_runnable "$requested"; then
        printf '%s\n' "$requested"
        return 0
      fi
      echo "Current llama.cpp model is not runnable: $requested"
      return 1
      ;;
    best|quality|vision|image|balanced|daily|fast|small)
      primary="$(_local_ai_resolve_model_target "$target")" || return 1

      case "$(_local_ai_profile_name "$LLAMA_CPP_MACHINE_PROFILE"):$target" in
        mac-mini-16g:best|mac-mini-16g:quality)
          candidates=$'gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf\ngemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\nQwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf'
          ;;
        mac-mini-16g:vision|mac-mini-16g:image)
          candidates=$'gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf\ngemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf'
          ;;
        mac-mini-16g:balanced|mac-mini-16g:daily)
          candidates=$'gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\ngemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\nQwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf'
          ;;
        mac-mini-16g:fast|mac-mini-16g:small)
          candidates=$'gemma-4-E4B-it-GGUF/gemma-4-E4B-it-UD-Q4_K_XL.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf'
          ;;
        *:best|*:quality)
          candidates=$'gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf\ngemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\nQwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf'
          ;;
        *:vision|*:image)
          candidates=$'gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\ngemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf'
          ;;
        *:balanced|*:daily)
          candidates=$'gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\ngemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\nQwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf\ngemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf'
          ;;
        *)
          candidates=$'gemma-4-E4B-it-GGUF/gemma-4-E4B-it-Q8_0.gguf\nQwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf\ngemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf\ngemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf'
          ;;
      esac

      for candidate in ${(f)candidates}; do
        if _local_ai_llama_cpp_model_runnable "$candidate"; then
          if [ "$candidate" != "$primary" ]; then
            echo "Requested $target, but $primary is not runnable locally. Using $candidate instead." >&2
          fi
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
    qwen|qwen27|qwen3.5-27b|*.gguf|*/*)
      requested="$(_local_ai_resolve_model_target "$target")" || return 1
      if _local_ai_llama_cpp_model_runnable "$requested"; then
        printf '%s\n' "$requested"
        return 0
      fi
      echo "Requested llama.cpp model is not runnable: $requested"
      return 1
      ;;
    *)
      echo "Unknown model target: $target"
      return 1
      ;;
  esac

  echo "No runnable llama.cpp model found for target: $target"
  return 1
}

_local_ai_run_llama_cpp_source() {
  local rel="$1"

  case "$rel" in
    gemma-4-31B-it-GGUF/*)
      run-gemma4-31b "$rel"
      ;;
    gemma-4-26B-A4B-it-GGUF/*)
      run-gemma4-26b "$rel"
      ;;
    gemma-4-E4B-it-GGUF/*)
      run-gemma4-e4b "$rel"
      ;;
    Qwen3.5-27B-GGUF/*)
      run-qwen35-27b "$rel"
      ;;
    *)
      llama-start "$rel"
      ;;
  esac
}

_local_ai_sync_env() {
  local source_model="$(_local_ai_source_model)"

  export LOCAL_AI_CONTEXT_LENGTH="$LLAMA_CPP_GEMMA_CTX_SIZE"

  case "$LOCAL_AI_PROVIDER" in
    lmstudio)
      export LOCAL_AI_PROVIDER="lmstudio"
      export LOCAL_AI_PROVIDER_URL="$LOCAL_AI_LMSTUDIO_BASE_URL"
      export LOCAL_AI_API_KEY="${LM_API_TOKEN:-local}"
      export LOCAL_AI_MODEL="$(_local_ai_lmstudio_model_key "$source_model")"
      ;;
    *)
      export LOCAL_AI_PROVIDER="llama.cpp"
      export LOCAL_AI_PROVIDER_URL="$LOCAL_AI_LLAMA_CPP_BASE_URL"
      export LOCAL_AI_API_KEY="local"
      export LOCAL_AI_MODEL="$LLAMA_CPP_SERVER_ALIAS"
      ;;
  esac

  export OPENAI_BASE_URL="$LOCAL_AI_PROVIDER_URL"
  export OPENAI_API_KEY="$LOCAL_AI_API_KEY"
}

_local_ai_lmstudio_model_exists() {
  local key="$1"

  command -v lms >/dev/null 2>&1 || return 1
  lms ls "$key" --json >/dev/null 2>&1
}

_local_ai_lmstudio_start_server() {
  command -v lms >/dev/null 2>&1 || {
    echo "LM Studio CLI not found"
    return 1
  }

  lms server start --bind "$LOCAL_AI_LMSTUDIO_HOST" --port "$LOCAL_AI_LMSTUDIO_PORT" >/dev/null 2>&1 || true
}

_local_ai_lmstudio_validate_model() {
  local rel="$1"
  local key="$2"
  local base="${rel##*/}"
  local identifier=""

  if ! _local_ai_model_has_mmproj "$rel"; then
    _local_ai_set_validation_status "$rel" "text" "text-only import"
    return 0
  fi

  base="${base%.gguf}"
  identifier="local-ai-validate-${base}-$$"

  _local_ai_lmstudio_start_server || return 1

  if lms load "$key" --context-length "$LOCAL_AI_CONTEXT_LENGTH" --identifier "$identifier" -y >/dev/null 2>&1; then
    lms unload "$identifier" >/dev/null 2>&1 || true
    _local_ai_set_validation_status "$rel" "lmstudio-capable" "multimodal import validated"
    echo "LM Studio multimodal validation passed for $rel"
    return 0
  fi

  _local_ai_set_validation_status "$rel" "llama.cpp-preferred" "LM Studio load failed for multimodal import"
  echo "LM Studio could not validate multimodal support for $rel; keep using llama.cpp for this model"
  return 0
}

lmstudio-import-llama-model() {
  local dry_run=0
  local rel=""
  local abs=""
  local key=""
  local cmd=()

  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
  esac

  rel="$1"

  if [ -z "$rel" ]; then
    echo "Usage: lmstudio-import-llama-model [--dry-run] <relative-gguf-path>"
    return 1
  fi

  case "$rel" in
    *mmproj*.gguf|mmproj*.gguf)
      echo "Skipping sidecar file: $rel"
      return 0
      ;;
  esac

  abs="$(_llama_require_model "$rel")" || return 1
  key="$(_local_ai_lmstudio_model_key "$rel")"
  cmd=(lms import "$abs" --yes --user-repo "$key" --symbolic-link)

  if [ "$dry_run" -eq 1 ]; then
    cmd+=(--dry-run)
  fi

  "${cmd[@]}" || return 1

  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi

  _local_ai_lmstudio_validate_model "$rel" "$key" || return 1
  _local_ai_sync_env >/dev/null 2>&1 || true
}

lmstudio-import-llama-all() {
  local dry_run=0
  local rel=""
  local total=0
  local failures=0

  case "$1" in
    --dry-run)
      dry_run=1
      ;;
  esac

  while IFS= read -r rel; do
    total=$((total + 1))

    if [ "$dry_run" -eq 1 ]; then
      lmstudio-import-llama-model --dry-run "$rel" || failures=$((failures + 1))
    else
      lmstudio-import-llama-model "$rel" || failures=$((failures + 1))
    fi
  done < <(_local_ai_list_importable_models | sed "s#^$LLAMA_CPP_MODELS/##")

  echo "LM Studio import summary: total=$total failures=$failures"

  if [ "$failures" -gt 0 ]; then
    return 1
  fi
}

lmstudio-list-imported() {
  local rel=""
  local key=""
  local imported=""
  local validation=""

  command -v lms >/dev/null 2>&1 || {
    echo "LM Studio CLI not found"
    return 1
  }

  while IFS= read -r rel; do
    key="$(_local_ai_lmstudio_model_key "$rel")"
    imported="no"
    validation="text"

    if _local_ai_lmstudio_model_exists "$key"; then
      imported="yes"
    fi

    if _local_ai_model_has_mmproj "$rel"; then
      validation="$(_local_ai_get_validation_status "$rel")"
      if [ -z "$validation" ]; then
        validation="unvalidated"
      fi
    fi

    printf '%s | imported=%s | validation=%s | source=%s\n' "$key" "$imported" "$validation" "$rel"
  done < <(_local_ai_list_importable_models | sed "s#^$LLAMA_CPP_MODELS/##")
}

local-ai-use() {
  local provider="${1:-}"

  case "$provider" in
    lmstudio|lm)
      export LOCAL_AI_PROVIDER="lmstudio"
      ;;
    llama.cpp|llama|llamacpp)
      export LOCAL_AI_PROVIDER="llama.cpp"
      ;;
    current|"")
      ;;
    *)
      echo "Usage: local-ai-use {lmstudio|llama.cpp|current}"
      return 1
      ;;
  esac

  _local_ai_sync_env
  echo "LOCAL_AI_PROVIDER -> $LOCAL_AI_PROVIDER"
  echo "LOCAL_AI_PROVIDER_URL -> $LOCAL_AI_PROVIDER_URL"
  echo "LOCAL_AI_MODEL -> $LOCAL_AI_MODEL"
}

local-ai-env() {
  _local_ai_sync_env

  echo "export LOCAL_AI_PROVIDER=$LOCAL_AI_PROVIDER"
  echo "export LOCAL_AI_PROVIDER_URL=$LOCAL_AI_PROVIDER_URL"
  echo "export LOCAL_AI_API_KEY=$LOCAL_AI_API_KEY"
  echo "export LOCAL_AI_MODEL=$LOCAL_AI_MODEL"
  echo "export LOCAL_AI_CONTEXT_LENGTH=$LOCAL_AI_CONTEXT_LENGTH"
  echo "export OPENAI_BASE_URL=$OPENAI_BASE_URL"
  echo "export OPENAI_API_KEY=$OPENAI_API_KEY"
}

local-ai-status() {
  local reachability="down"
  local api_key_mode="local"
  local imported="n/a"
  local source_model="$(_local_ai_source_model)"

  _local_ai_sync_env

  if [ "$LOCAL_AI_API_KEY" != "local" ]; then
    api_key_mode="token"
  fi

  case "$LOCAL_AI_PROVIDER" in
    lmstudio)
      if _local_ai_lmstudio_model_exists "$LOCAL_AI_MODEL"; then
        imported="yes"
      else
        imported="no"
      fi

      if [ "$api_key_mode" = "token" ]; then
        curl -fsS -H "Authorization: Bearer $LOCAL_AI_API_KEY" "$LOCAL_AI_PROVIDER_URL/models" >/dev/null 2>&1 && reachability="up"
      else
        curl -fsS "$LOCAL_AI_PROVIDER_URL/models" >/dev/null 2>&1 && reachability="up"
      fi
      ;;
    *)
      curl -fsS "$(_llama_endpoint)/health" >/dev/null 2>&1 && reachability="up"
      ;;
  esac

  echo "LOCAL_AI_PROVIDER:       $LOCAL_AI_PROVIDER"
  echo "LOCAL_AI_PROVIDER_URL:   $LOCAL_AI_PROVIDER_URL"
  echo "LOCAL_AI_API_KEY_MODE:   $api_key_mode"
  echo "LOCAL_AI_MODEL:          $LOCAL_AI_MODEL"
  echo "LOCAL_AI_SOURCE_MODEL:   $source_model"
  echo "LOCAL_AI_CONTEXT_LENGTH: $LOCAL_AI_CONTEXT_LENGTH"
  echo "Local AI server:         $reachability"

  if [ "$LOCAL_AI_PROVIDER" = "lmstudio" ]; then
    echo "LM Studio imported:      $imported"
  fi
}

local-ai-load() {
  local target="${1:-current}"
  local rel=""
  local key=""
  local validation=""

  case "$LOCAL_AI_PROVIDER" in
    lmstudio)
      rel="$(_local_ai_resolve_model_target "$target")" || return 1
      if _local_ai_is_named_preset "$target"; then
        _local_ai_ensure_model_assets "$rel" || return 1
      fi
      _llama_switch_default_model "$rel" || return 1
      key="$(_local_ai_lmstudio_model_key "$rel")"

      if ! _local_ai_lmstudio_model_exists "$key"; then
        echo "Importing $rel into LM Studio..."
        lmstudio-import-llama-model "$rel" || return 1
      fi

      if _local_ai_model_has_mmproj "$rel"; then
        validation="$(_local_ai_get_validation_status "$rel")"

        if [ "$validation" != "lmstudio-capable" ]; then
          _local_ai_lmstudio_validate_model "$rel" "$key" || return 1
          validation="$(_local_ai_get_validation_status "$rel")"
        fi

        if [ "$validation" = "llama.cpp-preferred" ]; then
          echo "LM Studio is not validated for multimodal use with $rel"
          echo "Use: local-ai-use llama.cpp && local-ai-load $target"
          return 1
        fi
      fi

      _local_ai_lmstudio_start_server || return 1
      lms load "$key" --context-length "$LOCAL_AI_CONTEXT_LENGTH" -y || return 1
      _local_ai_sync_env
      echo "LM Studio model loaded: $key"
      ;;
    *)
      rel="$(_local_ai_resolve_model_target "$target")" || return 1
      if _local_ai_is_named_preset "$target"; then
        _local_ai_ensure_model_assets "$rel" || return 1
      fi
      rel="$(_local_ai_resolve_llama_cpp_target "$target")" || return 1
      _llama_switch_default_model "$rel" || return 1
      _local_ai_run_llama_cpp_source "$rel" || return 1
      _local_ai_sync_env
      ;;
  esac
}

alias qwen27='run-qwen35-27b'
alias gemma4-best='llama-switch best'
alias gemma4-vision='llama-switch vision'
alias gemma4-balanced='llama-switch balanced'
alias gemma4-fast='llama-switch fast'
alias gemma4-mini='run-gemma4-e4b'
alias gemma4-profile-mini='llama-profile mini'
alias gemma4-profile-macbook-pro='llama-profile macbook-pro'
alias gemma4-profile-desktop='llama-profile macbook-pro'
alias gemma4-switch-best='llama-switch best'
alias gemma4-switch-vision='llama-switch vision'
alias gemma4-switch-balanced='llama-switch balanced'
alias gemma4-switch-fast='llama-switch fast'
alias gemma4-best-pull='llama-pull-gemma4-31b'
alias gemma4-balanced-pull='llama-pull-gemma4-26b'
alias gemma4-fast-pull='llama-pull-gemma4-e4b'
alias gemma4-mini-pull='llama-pull-gemma4-e4b q8'
alias gemma4-31b-pull='llama-pull-gemma4-31b'
alias gemma4-31b-mmproj-pull='llama-pull-gemma4-31b-mmproj'
alias gemma4-26b-pull='llama-pull-gemma4-26b'
alias gemma4-26b-mmproj-pull='llama-pull-gemma4-26b-mmproj'
alias gemma4-e4b-pull='llama-pull-gemma4-e4b'
alias qwen27-pull='llama-pull-qwen35-27b-q5'
alias llama-thinking-on='llama-thinking on'
alias llama-thinking-off='llama-thinking off'

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
