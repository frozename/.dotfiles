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

_llama_backup_root() {
  printf '%s\n' "$LLAMA_CPP_ROOT/.backups"
}

_llama_backup_binaries() {
  local backup_root="$(_llama_backup_root)"
  local timestamp
  local backup_dir
  local copied=0
  local bin

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$backup_root/$timestamp"

  mkdir -p "$backup_dir" || return 1

  for bin in llama-server llama-cli llama-bench; do
    if [ -x "$LLAMA_CPP_BIN/$bin" ]; then
      cp -p "$LLAMA_CPP_BIN/$bin" "$backup_dir/$bin" || return 1
      copied=1
    fi
  done

  if [ "$copied" -eq 0 ]; then
    rmdir "$backup_dir" >/dev/null 2>&1 || true
    return 0
  fi

  printf '%s\n' "$backup_dir"
}

_llama_restore_binaries() {
  local backup_dir="$1"
  local bin_path

  if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
    return 0
  fi

  mkdir -p "$LLAMA_CPP_BIN" || return 1

  for bin_path in "$backup_dir"/*; do
    if [ -f "$bin_path" ]; then
      cp -p "$bin_path" "$LLAMA_CPP_BIN/${bin_path:t}" || return 1
    fi
  done
}

_llama_smoke_test_binaries() {
  local server_bin="$LLAMA_CPP_BIN/llama-server"

  if [ ! -x "$server_bin" ]; then
    echo "llama-server binary not found: $server_bin"
    return 1
  fi

  "$server_bin" --help >/dev/null 2>&1 || {
    echo "llama-server smoke test failed"
    return 1
  }
}

_llama_bench_profile_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/llama-bench-profiles.tsv"
}

_llama_bench_history_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/llama-bench-history.tsv"
}

_llama_bench_profile_get() {
  local rel="$1"
  local file="$(_llama_bench_profile_file)"

  if [ ! -f "$file" ]; then
    return 1
  fi

  awk -F '\t' -v rel="$rel" '$1 == rel { print $2 }' "$file" | tail -n 1
}

_llama_bench_history_append() {
  local rel="$1"
  local profile="$2"
  local gen_ts="$3"
  local prompt_ts="$4"
  local file="$(_llama_bench_history_file)"

  _local_ai_ensure_runtime_dir
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" \
    "$rel" \
    "$profile" \
    "$gen_ts" \
    "$prompt_ts" \
    "$(_llama_server_profile_args "$profile")" >> "$file"
}

_llama_bench_profile_set() {
  local rel="$1"
  local profile="$2"
  local gen_ts="$3"
  local prompt_ts="$4"
  local file="$(_llama_bench_profile_file)"
  local tmp

  _local_ai_ensure_runtime_dir
  tmp="$(mktemp "${TMPDIR:-/tmp}/llama-bench-profiles.XXXXXX")" || return 1

  if [ -f "$file" ]; then
    awk -F '\t' -v rel="$rel" '$1 != rel { print $0 }' "$file" > "$tmp"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$rel" "$profile" "$gen_ts" "$prompt_ts" "$(date +%Y-%m-%dT%H:%M:%S%z)" >> "$tmp"
  mv "$tmp" "$file"
  _llama_bench_history_append "$rel" "$profile" "$gen_ts" "$prompt_ts"
}

_llama_server_profile_args() {
  case "$1" in
    throughput)
      printf '%s\n' "-fa on -b 4096 -ub 1024"
      ;;
    conservative)
      printf '%s\n' "-fa off -b 1024 -ub 256"
      ;;
    default|*)
      printf '%s\n' "-fa on -b 2048 -ub 512"
      ;;
  esac
}

_llama_bench_profile_args() {
  case "$1" in
    throughput)
      printf '%s\n' "-fa 1 -b 4096 -ub 1024"
      ;;
    conservative)
      printf '%s\n' "-fa 0 -b 1024 -ub 256"
      ;;
    default|*)
      printf '%s\n' "-fa 1 -b 2048 -ub 512"
      ;;
  esac
}

_llama_tuned_profile_enabled() {
  case "${LLAMA_CPP_USE_TUNED_ARGS:-true}" in
    0|false|FALSE|no|NO|off|OFF)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

_llama_start_has_mmproj() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      --mmproj|-mm|--mmproj-url|--mmproj-auto)
        return 0
        ;;
    esac
  done

  return 1
}

_llama_safe_retry_args() {
  printf '%s\n' "--flash-attn off --no-cache-prompt --parallel 1 --no-cont-batching --no-mmproj-offload --no-warmup"
}

_llama_launch_server_background() {
  local model_path="$1"
  shift

  nohup llama-server \
    -m "$model_path" \
    --alias "$LLAMA_CPP_SERVER_ALIAS" \
    --host "$LLAMA_CPP_HOST" \
    --port "$LLAMA_CPP_PORT" \
    -ngl 999 \
    "$@" > "$LLAMA_CPP_LOGS/server.log" 2>&1 &

  printf '%s\n' "$!"
}

_llama_wait_for_ready() {
  local pid="$1"
  local health_endpoint="$2"
  local timeout_seconds="${3:-60}"
  local attempt=0
  local http_code=""

  while [ "$attempt" -lt "$timeout_seconds" ]; do
    http_code="$(curl -fsS -o /dev/null -w "%{http_code}" "$health_endpoint" 2>/dev/null || true)"

    case "$http_code" in
      200)
        return 0
        ;;
      503)
        ;;
      *)
        if ! kill -0 "$pid" >/dev/null 2>&1; then
          return 1
        fi
        ;;
    esac

    attempt=$((attempt + 1))
    sleep 1
  done

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    return 1
  fi

  return 1
}

llama-bench-preset() {
  local target="${1:-current}"
  local rel=""
  local model_path=""
  local profile=""
  local output=""
  local gen_ts=""
  local prompt_ts=""
  local best_profile=""
  local best_gen_ts="-1"
  local best_prompt_ts="-1"
  local bench_args_str=""

  command -v jq >/dev/null 2>&1 || {
    echo "jq is required for llama-bench-preset"
    return 1
  }

  if [ ! -x "$LLAMA_CPP_BIN/llama-bench" ]; then
    echo "llama-bench binary not found: $LLAMA_CPP_BIN/llama-bench"
    return 1
  fi

  rel="$(_local_ai_resolve_model_target "$target")" || return 1
  if _local_ai_is_named_preset "$target"; then
    _local_ai_ensure_model_assets "$rel" || return 1
  fi

  model_path="$(_llama_require_model "$rel")" || return 1

  for profile in default throughput conservative; do
    bench_args_str="$(_llama_bench_profile_args "$profile")"
    echo "Benchmarking $rel with profile '$profile'..."
    output="$("$LLAMA_CPP_BIN/llama-bench" -m "$model_path" -pg 256,64 -r 1 -ngl 999 ${(z)bench_args_str} -o jsonl 2>/dev/null)" || {
      echo "Benchmark failed for profile '$profile'"
      continue
    }

    gen_ts="$(printf '%s\n' "$output" | jq -sr 'map(select(.n_gen > 0)) | first.avg_ts // -1')"
    prompt_ts="$(printf '%s\n' "$output" | jq -sr 'map(select(.n_prompt > 0 and .n_gen == 0)) | first.avg_ts // -1')"

    if [ "$(printf '%.0f\n' "$gen_ts")" -gt "$(printf '%.0f\n' "$best_gen_ts")" ] || {
      [ "$(printf '%.0f\n' "$gen_ts")" -eq "$(printf '%.0f\n' "$best_gen_ts")" ] &&
      [ "$(printf '%.0f\n' "$prompt_ts")" -gt "$(printf '%.0f\n' "$best_prompt_ts")" ]
    }; then
      best_profile="$profile"
      best_gen_ts="$gen_ts"
      best_prompt_ts="$prompt_ts"
    fi
  done

  if [ -z "$best_profile" ]; then
    echo "No successful benchmark profiles for $rel"
    return 1
  fi

  _llama_bench_profile_set "$rel" "$best_profile" "$best_gen_ts" "$best_prompt_ts" || return 1
  echo "Saved tuned launch profile for $rel"
  echo "profile=$best_profile gen_tps=$best_gen_ts prompt_tps=$best_prompt_ts"
}

llama-bench-show() {
  local target="${1:-current}"
  local rel=""
  local profile=""
  local file="$(_llama_bench_profile_file)"

  rel="$(_local_ai_resolve_model_target "$target")" || return 1
  profile="$(_llama_bench_profile_get "$rel")"

  if [ -z "$profile" ]; then
    echo "No tuned launch profile recorded for $rel"
    return 1
  fi

  awk -F '\t' -v rel="$rel" '$1 == rel { printf "model=%s\nprofile=%s\ngen_tps=%s\nprompt_tps=%s\nupdated_at=%s\n", $1, $2, $3, $4, $5 }' "$file" | tail -n 5
  echo "launch_args=$(_llama_server_profile_args "$profile")"
}

llama-bench-history() {
  local target="${1:-all}"
  local file="$(_llama_bench_history_file)"

  if [ ! -f "$file" ]; then
    echo "No benchmark history recorded yet"
    return 1
  fi

  if [ "$target" = "all" ]; then
    awk -F '\t' '{ printf "%s | %s | profile=%s | gen_tps=%s | prompt_tps=%s | launch_args=%s\n", $1, $2, $3, $4, $5, $6 }' "$file" | tail -n 20
    return 0
  fi

  local rel=""
  rel="$(_local_ai_resolve_model_target "$target")" || return 1
  awk -F '\t' -v rel="$rel" '$2 == rel { printf "%s | %s | profile=%s | gen_tps=%s | prompt_tps=%s | launch_args=%s\n", $1, $2, $3, $4, $5, $6 }' "$file" | tail -n 20
}

llama-update-safe() {
  local backup_dir=""
  local previous_commit=""
  local current_commit=""

  cd "$LLAMA_CPP_SRC" || return 1

  previous_commit="$(git rev-parse --short HEAD 2>/dev/null || true)"
  backup_dir="$(_llama_backup_binaries)" || return 1

  if git pull --rebase && llama-build && _llama_smoke_test_binaries; then
    current_commit="$(git rev-parse --short HEAD 2>/dev/null || true)"
    echo "llama.cpp update succeeded: ${previous_commit:-unknown} -> ${current_commit:-unknown}"
    if [ -n "$backup_dir" ]; then
      echo "Binary backup saved at: $backup_dir"
    fi
    return 0
  fi

  echo "llama.cpp update failed; restoring previous binaries..."

  if [ -n "$backup_dir" ]; then
    _llama_restore_binaries "$backup_dir" || {
      echo "Failed to restore binaries from $backup_dir"
      return 1
    }
  fi

  if _llama_smoke_test_binaries; then
    echo "Previous llama.cpp binaries restored successfully."
  else
    echo "Restored llama.cpp binaries did not pass smoke test."
    return 1
  fi

  current_commit="$(git rev-parse --short HEAD 2>/dev/null || true)"
  echo "Working source commit is now: ${current_commit:-unknown}"
  echo "Previous known-good binary build came from: ${previous_commit:-unknown}"
  return 1
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
  local timeout_seconds=60
  local tuned_profile=""
  local tuned_args_str=""
  local safe_retry_args_str=""
  local launch_args=()
  local retry_args=()
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

  if _llama_tuned_profile_enabled; then
    tuned_profile="$(_llama_bench_profile_get "$model")"
    if [ -n "$tuned_profile" ]; then
      tuned_args_str="$(_llama_server_profile_args "$tuned_profile")"
      launch_args+=(${(z)tuned_args_str})
      echo "Using tuned launch profile '$tuned_profile' for $model"
    else
      launch_args+=(${(z)$(_llama_server_profile_args default)})
    fi
  else
    launch_args+=(${(z)$(_llama_server_profile_args default)})
  fi

  launch_args+=("$@")
  pid="$(_llama_launch_server_background "$model_path" "${launch_args[@]}")"

  if _llama_wait_for_ready "$pid" "$health_endpoint" "$timeout_seconds"; then
    llama-status
    return 0
  fi

  if _llama_start_has_mmproj "${launch_args[@]}"; then
    echo "Vision model failed to become ready; retrying with safer server flags..."
    safe_retry_args_str="$(_llama_safe_retry_args)"
    retry_args=("${launch_args[@]}" ${(z)safe_retry_args_str})

    llama-stop >/dev/null 2>&1 || true
    pid="$(_llama_launch_server_background "$model_path" "${retry_args[@]}")"

    if _llama_wait_for_ready "$pid" "$health_endpoint" "$timeout_seconds"; then
      echo "llama.cpp recovered with safe vision flags"
      llama-status
      return 0
    fi
  fi

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    echo "llama.cpp exited before becoming ready"
  else
    echo "llama.cpp readiness check timed out after ${timeout_seconds}s"
  fi
  tail -n 50 "$LLAMA_CPP_LOGS/server.log" 2>/dev/null
  return 1
}

_llama_keep_alive_pid_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/llama-keep-alive.pid"
}

_llama_keep_alive_stop_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/llama-keep-alive.stop"
}

_llama_keep_alive_state_file() {
  printf '%s\n' "$LOCAL_AI_RUNTIME_DIR/llama-keep-alive.state"
}

_llama_keep_alive_log_file() {
  printf '%s\n' "$LLAMA_CPP_LOGS/keep-alive.log"
}

_llama_keep_alive_write_state() {
  local target="$1"
  local rel="$2"
  local state="$3"
  local restarts="$4"
  local backoff="$5"
  local file="$(_llama_keep_alive_state_file)"

  _local_ai_ensure_runtime_dir
  mkdir -p "$LLAMA_CPP_LOGS"

  printf 'updated_at=%s\ntarget=%s\nmodel=%s\nstate=%s\nrestarts=%s\nbackoff_seconds=%s\nlog=%s\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" \
    "$target" \
    "$rel" \
    "$state" \
    "$restarts" \
    "$backoff" \
    "$(_llama_keep_alive_log_file)" > "$file"
}

_llama_keep_alive_running_pid() {
  local pid_file="$(_llama_keep_alive_pid_file)"
  local pid=""

  [ -f "$pid_file" ] || return 1
  pid="$(cat "$pid_file" 2>/dev/null)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" >/dev/null 2>&1 || return 1
  printf '%s\n' "$pid"
}

_llama_keep_alive_monitor_ready() {
  local interval="${1:-$LLAMA_CPP_KEEP_ALIVE_INTERVAL}"
  local health_endpoint="$(_llama_endpoint)/health"
  local stop_file="$(_llama_keep_alive_stop_file)"
  local http_code=""

  while :; do
    if [ -f "$stop_file" ]; then
      return 1
    fi

    http_code="$(curl -fsS -o /dev/null -w "%{http_code}" "$health_endpoint" 2>/dev/null || true)"
    case "$http_code" in
      200|503)
        sleep "$interval"
        ;;
      *)
        return 1
        ;;
    esac
  done
}

_llama_keep_alive_worker() {
  local target="${1:-current}"
  local interval="${LLAMA_CPP_KEEP_ALIVE_INTERVAL:-5}"
  local max_backoff="${LLAMA_CPP_KEEP_ALIVE_MAX_BACKOFF:-30}"
  local stop_file="$(_llama_keep_alive_stop_file)"
  local pid_file="$(_llama_keep_alive_pid_file)"
  local restarts=0
  local backoff=1
  local requested=""
  local rel=""

  trap 'llama-stop >/dev/null 2>&1 || true; rm -f "$pid_file" "$stop_file"; _llama_keep_alive_write_state "$target" "${rel:-unknown}" "stopped" "$restarts" "$backoff"; exit 0' INT TERM EXIT

  while :; do
    [ -f "$stop_file" ] && break

    requested="$(_local_ai_resolve_model_target "$target")" || {
      _llama_keep_alive_write_state "$target" "unresolved" "resolve-failed" "$restarts" "$backoff"
      sleep "$backoff"
      if [ "$backoff" -lt "$max_backoff" ]; then
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$max_backoff" ] && backoff="$max_backoff"
      fi
      continue
    }

    if _local_ai_is_named_preset "$target"; then
      _local_ai_ensure_model_assets "$requested" || {
        _llama_keep_alive_write_state "$target" "$requested" "asset-fetch-failed" "$restarts" "$backoff"
        sleep "$backoff"
        if [ "$backoff" -lt "$max_backoff" ]; then
          backoff=$((backoff * 2))
          [ "$backoff" -gt "$max_backoff" ] && backoff="$max_backoff"
        fi
        continue
      }
    fi

    rel="$(_local_ai_resolve_llama_cpp_target "$target")" || {
      _llama_keep_alive_write_state "$target" "$requested" "not-runnable" "$restarts" "$backoff"
      sleep "$backoff"
      if [ "$backoff" -lt "$max_backoff" ]; then
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$max_backoff" ] && backoff="$max_backoff"
      fi
      continue
    }

    _llama_keep_alive_write_state "$target" "$rel" "starting" "$restarts" "$backoff"
    _llama_switch_default_model "$rel" >/dev/null 2>&1 || true

    if _local_ai_run_llama_cpp_source "$rel"; then
      backoff=1
      _llama_keep_alive_write_state "$target" "$rel" "ready" "$restarts" "$backoff"

      if _llama_keep_alive_monitor_ready "$interval"; then
        continue
      fi

      [ -f "$stop_file" ] && break
      restarts=$((restarts + 1))
      _llama_keep_alive_write_state "$target" "$rel" "restart-pending" "$restarts" "$backoff"
      sleep "$backoff"
      if [ "$backoff" -lt "$max_backoff" ]; then
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$max_backoff" ] && backoff="$max_backoff"
      fi
      continue
    fi

    restarts=$((restarts + 1))
    _llama_keep_alive_write_state "$target" "$rel" "start-failed" "$restarts" "$backoff"
    sleep "$backoff"
    if [ "$backoff" -lt "$max_backoff" ]; then
      backoff=$((backoff * 2))
      [ "$backoff" -gt "$max_backoff" ] && backoff="$max_backoff"
    fi
  done

  return 0
}

llama-keep-alive() {
  local target="${1:-current}"
  local pid=""
  local log_file="$(_llama_keep_alive_log_file)"

  _local_ai_ensure_runtime_dir
  mkdir -p "$LLAMA_CPP_LOGS"

  pid="$(_llama_keep_alive_running_pid 2>/dev/null || true)"
  if [ -n "$pid" ]; then
    echo "llama.cpp keep-alive is already running: pid=$pid"
    return 1
  fi

  rm -f "$(_llama_keep_alive_stop_file)"
  _llama_keep_alive_write_state "$target" "pending" "launching" 0 1
  ( _llama_keep_alive_worker "$target" ) >> "$log_file" 2>&1 &!
  pid="$!"

  if [ -n "$pid" ]; then
    printf '%s\n' "$pid" > "$(_llama_keep_alive_pid_file)"
  fi

  echo "llama.cpp keep-alive started"
  echo "target=$target"
  echo "pid=${pid:-unknown}"
  echo "log=$log_file"
}

llama-keep-alive-stop() {
  local pid=""
  local stop_file="$(_llama_keep_alive_stop_file)"
  local pid_file="$(_llama_keep_alive_pid_file)"
  local state_file="$(_llama_keep_alive_state_file)"
  local waited=0

  pid="$(_llama_keep_alive_running_pid 2>/dev/null || true)"

  if [ -z "$pid" ]; then
    rm -f "$pid_file" "$stop_file"
    echo "llama.cpp keep-alive is not running"
    return 0
  fi

  : > "$stop_file"

  while kill -0 "$pid" >/dev/null 2>&1 && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done

  if kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
  fi

  llama-stop >/dev/null 2>&1 || true
  rm -f "$pid_file" "$stop_file"
  [ -f "$state_file" ] && sed -n '1,20p' "$state_file"
}

llama-keep-alive-status() {
  local pid=""
  local state_file="$(_llama_keep_alive_state_file)"

  pid="$(_llama_keep_alive_running_pid 2>/dev/null || true)"

  if [ -n "$pid" ]; then
    echo "llama.cpp keep-alive: running (pid=$pid)"
  else
    echo "llama.cpp keep-alive: stopped"
  fi

  if [ -f "$state_file" ]; then
    sed -n '1,20p' "$state_file"
  fi
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

_llama_auto_tune_on_pull_enabled() {
  case "${LLAMA_CPP_AUTO_TUNE_ON_PULL:-true}" in
    0|false|FALSE|no|NO|off|OFF)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

_llama_maybe_tune_after_pull() {
  local rel="$1"
  local was_missing="${2:-0}"
  local profile=""

  if [ "$was_missing" -ne 1 ]; then
    return 0
  fi

  _llama_auto_tune_on_pull_enabled || return 0

  if [ ! -x "$LLAMA_CPP_BIN/llama-bench" ]; then
    echo "Skipping auto-tune for $rel: llama-bench binary not found"
    return 0
  fi

  profile="$(_llama_bench_profile_get "$rel")"
  if [ -n "$profile" ]; then
    echo "Tuned launch profile already exists for $rel"
    return 0
  fi

  echo "Running auto-tune benchmark for $rel..."
  llama-bench-preset "$rel" || {
    echo "Auto-tune benchmark failed for $rel"
    return 0
  }
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

  mmproj="$(_llama_find_mmproj "$LLAMA_CPP_MODELS/$model_dir" "$rel")" || {
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
  local model_ref="$2"
  local model_path=""
  local candidate
  local best_candidate=""
  local best_score=-1
  local score=0

  case "$model_ref" in
    "")
      ;;
    /*)
      model_path="$model_ref"
      ;;
    *)
      model_path="$LLAMA_CPP_MODELS/$model_ref"
      ;;
  esac

  for candidate in "$model_dir"/mmproj*.gguf "$model_dir"/*mmproj*.gguf; do
    [ -f "$candidate" ] || continue
    score="$(_llama_mmproj_match_score "$model_path" "$candidate")"
    if [ "$score" -gt "$best_score" ]; then
      best_candidate="$candidate"
      best_score="$score"
    fi
  done

  if [ -n "$best_candidate" ]; then
    printf '%s\n' "$best_candidate"
    return 0
  fi

  return 1
}

_llama_gguf_metadata_value() {
  local gguf="$1"
  local key="$2"

  [ -f "$gguf" ] || return 1
  command -v strings >/dev/null 2>&1 || return 1

  strings "$gguf" 2>/dev/null | awk -v key="$key" '
    {
      gsub(/[[:cntrl:]]/, "", $0)
      if (prev == key && length($0) > 0) {
        print $0
        exit
      }
      prev = $0
    }
  '
}

_llama_mmproj_match_score() {
  local model_path="$1"
  local mmproj_path="$2"
  local score=0
  local model_basename=""
  local mmproj_basename=""
  local model_base_name=""
  local mmproj_base_name=""
  local model_repo=""
  local mmproj_repo=""
  local mmproj_arch=""

  [ -f "$mmproj_path" ] || {
    printf '0\n'
    return 0
  }

  case "${mmproj_path:t}" in
    mmproj-BF16.gguf)
      score=$((score + 2))
      ;;
    mmproj-F16.gguf)
      score=$((score + 1))
      ;;
  esac

  if [ -f "$model_path" ]; then
    model_basename="$(_llama_gguf_metadata_value "$model_path" "general.basename")"
    mmproj_basename="$(_llama_gguf_metadata_value "$mmproj_path" "general.basename")"
    model_base_name="$(_llama_gguf_metadata_value "$model_path" "general.base_model.0.name")"
    mmproj_base_name="$(_llama_gguf_metadata_value "$mmproj_path" "general.base_model.0.name")"
    model_repo="$(_llama_gguf_metadata_value "$model_path" "general.base_model.0.repo_url")"
    mmproj_repo="$(_llama_gguf_metadata_value "$mmproj_path" "general.base_model.0.repo_url")"

    [ -n "$model_basename" ] && [ "$model_basename" = "$mmproj_basename" ] && score=$((score + 8))
    [ -n "$model_base_name" ] && [ "$model_base_name" = "$mmproj_base_name" ] && score=$((score + 8))
    [ -n "$model_repo" ] && [ "$model_repo" = "$mmproj_repo" ] && score=$((score + 6))
  fi

  mmproj_arch="$(_llama_gguf_metadata_value "$mmproj_path" "general.architecture")"
  [ "$mmproj_arch" = "clip" ] && score=$((score + 3))

  printf '%s\n' "$score"
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
  local quant="${1:-recommended}"
  local model_file=""
  local rel=""
  local was_missing=0

  if [ "$quant" = "recommended" ] || [ "$quant" = "default" ] || [ "$quant" = "auto" ]; then
    quant="$(_llama_recommended_quant_for_target 26b)"
  fi

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

  rel="gemma-4-26B-A4B-it-GGUF/$model_file"
  [ -f "$LLAMA_CPP_MODELS/$rel" ] || was_missing=1
  mkdir -p "$target"
  hf download unsloth/gemma-4-26B-A4B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
  _llama_maybe_tune_after_pull "$rel" "$was_missing"
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
  local quant="${1:-recommended}"
  local model_file=""
  local rel=""
  local was_missing=0

  if [ "$quant" = "recommended" ] || [ "$quant" = "default" ] || [ "$quant" = "auto" ]; then
    quant="$(_llama_recommended_quant_for_target e4b)"
  fi

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

  rel="gemma-4-E4B-it-GGUF/$model_file"
  [ -f "$LLAMA_CPP_MODELS/$rel" ] || was_missing=1
  mkdir -p "$target"
  hf download unsloth/gemma-4-E4B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
  _llama_maybe_tune_after_pull "$rel" "$was_missing"
}

llama-pull-gemma4-31b() {
  local target="$LLAMA_CPP_MODELS/gemma-4-31B-it-GGUF"
  local quant="${1:-recommended}"
  local model_file=""
  local rel=""
  local was_missing=0

  if [ "$quant" = "recommended" ] || [ "$quant" = "default" ] || [ "$quant" = "auto" ]; then
    quant="$(_llama_recommended_quant_for_target 31b)"
  fi

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

  rel="gemma-4-31B-it-GGUF/$model_file"
  [ -f "$LLAMA_CPP_MODELS/$rel" ] || was_missing=1
  mkdir -p "$target"
  hf download unsloth/gemma-4-31B-it-GGUF \
    "$model_file" \
    mmproj-BF16.gguf \
    --local-dir "$target"
  _llama_maybe_tune_after_pull "$rel" "$was_missing"
}

llama-pull-qwen35-27b-q5() {
  local target="$LLAMA_CPP_MODELS/Qwen3.5-27B-GGUF"
  local rel="Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-Q5_K_XL.gguf"
  local was_missing=0

  [ -f "$LLAMA_CPP_MODELS/$rel" ] || was_missing=1
  mkdir -p "$target"
  hf download unsloth/Qwen3.5-27B-GGUF \
    Qwen3.5-27B-UD-Q5_K_XL.gguf \
    --local-dir "$target"
  _llama_maybe_tune_after_pull "$rel" "$was_missing"
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

  _llama_find_mmproj "$model_dir" "$rel" >/dev/null 2>&1
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

_llama_recommended_quant_for_target() {
  local target="${1:-current}"
  local rel=""
  local profile="$(_local_ai_profile_name "$LLAMA_CPP_MACHINE_PROFILE")"

  case "$target" in
    31b|gemma4-31b|gemma-4-31b)
      rel="gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf"
      ;;
    26b|gemma4-26b|gemma-4-26b)
      rel="gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
      ;;
    e4b|gemma4-e4b|gemma-4-e4b)
      if [ "$profile" = "mac-mini-16g" ]; then
        printf '%s\n' "q4"
      else
        printf '%s\n' "q8"
      fi
      return 0
      ;;
    qwen|qwen27|qwen3.5-27b)
      printf '%s\n' "q5"
      return 0
      ;;
    *)
      rel="$(_local_ai_resolve_model_target "$target")" || return 1
      ;;
  esac

  case "$rel" in
    gemma-4-31B-it-GGUF/*Q8_0.gguf)
      printf '%s\n' "q8"
      ;;
    gemma-4-31B-it-GGUF/*Q6*.gguf)
      printf '%s\n' "q6"
      ;;
    gemma-4-31B-it-GGUF/*Q5*.gguf)
      printf '%s\n' "q5"
      ;;
    gemma-4-31B-it-GGUF/*)
      printf '%s\n' "q4"
      ;;
    gemma-4-26B-A4B-it-GGUF/*Q8_0.gguf)
      printf '%s\n' "q8"
      ;;
    gemma-4-26B-A4B-it-GGUF/*Q6*.gguf)
      printf '%s\n' "q6"
      ;;
    gemma-4-26B-A4B-it-GGUF/*Q5*.gguf)
      printf '%s\n' "q5"
      ;;
    gemma-4-26B-A4B-it-GGUF/*)
      printf '%s\n' "q4"
      ;;
    gemma-4-E4B-it-GGUF/*Q8_0.gguf)
      printf '%s\n' "q8"
      ;;
    gemma-4-E4B-it-GGUF/*Q6*.gguf)
      printf '%s\n' "q6"
      ;;
    gemma-4-E4B-it-GGUF/*Q5_K_M.gguf)
      printf '%s\n' "q5km"
      ;;
    gemma-4-E4B-it-GGUF/*Q5*.gguf)
      printf '%s\n' "q5"
      ;;
    gemma-4-E4B-it-GGUF/*Q4_K_M.gguf)
      printf '%s\n' "q4km"
      ;;
    gemma-4-E4B-it-GGUF/*)
      printf '%s\n' "q4"
      ;;
    Qwen3.5-27B-GGUF/*)
      printf '%s\n' "q5"
      ;;
    *)
      echo "No recommended quant mapping for $target"
      return 1
      ;;
  esac
}

llama-recommend-quant() {
  local target="${1:-current}"
  local quant=""
  local rel=""

  quant="$(_llama_recommended_quant_for_target "$target")" || return 1
  rel="$(_local_ai_resolve_model_target "$target")" 2>/dev/null || true

  if [ -n "$rel" ]; then
    echo "target=$target"
    echo "model=$rel"
  fi
  echo "recommended_quant=$quant"
}

llama-pull-recommended() {
  local target="${1:-current}"
  local quant=""
  local rel=""

  rel="$(_local_ai_resolve_model_target "$target")" || return 1
  quant="$(_llama_recommended_quant_for_target "$target")" || return 1

  case "$rel" in
    gemma-4-31B-it-GGUF/*)
      llama-pull-gemma4-31b "$quant"
      ;;
    gemma-4-26B-A4B-it-GGUF/*)
      llama-pull-gemma4-26b "$quant"
      ;;
    gemma-4-E4B-it-GGUF/*)
      llama-pull-gemma4-e4b "$quant"
      ;;
    Qwen3.5-27B-GGUF/*)
      llama-pull-qwen35-27b-q5
      ;;
    *)
      echo "No recommended pull mapping for $target"
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
alias gemma4-best-pull='llama-pull-recommended best'
alias gemma4-balanced-pull='llama-pull-recommended balanced'
alias gemma4-fast-pull='llama-pull-recommended fast'
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
