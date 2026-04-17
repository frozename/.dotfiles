# dotfiles

This repo is the public version of the shell setup I use every day on macOS.

It is mostly a modular `zsh` setup, a tiny deployment script, and a bunch of helpers for JavaScript tooling, hopping between repos, and messing around with local LLMs. It is not trying to be some giant framework for everyone. It is just the setup that fits how I like to work.

## What is here

- `zshrc`: the top-level entrypoint that loads the modules in `~/.zsh/`
- `zsh/env.zsh`: environment variables, editor setup, cache locations, and shared paths
- `zsh/shell.zsh`: `oh-my-zsh` plugins, history settings, and shell behavior
- `zsh/tools.zsh`: tool bootstrap for `zoxide`, `fzf`, `atuin`, `direnv`, `starship`, and a few navigation aliases
- `zsh/bun.zsh`: `fnm`/`bun` helpers and automatic `.bumrc` version switching
- `zsh/repos.zsh`: shortcuts for jumping into work and personal repositories
- `zsh/aliases.zsh`: lightweight git, package manager, and Docker aliases
- `zsh/llm.zsh`: helpers for local Ollama and `llama.cpp` workflows
- `apply-baselines.sh`: copies tracked files into their matching paths under `$HOME`

## How it works

`apply-baselines.sh` maps repo paths to hidden paths in `$HOME`.

Examples:

- `zshrc` -> `~/.zshrc`
- `zsh/env.zsh` -> `~/.zsh/env.zsh`
- `.config/starship.toml` -> `~/.config/starship.toml`

Useful commands:

```bash
./apply-baselines.sh --list
./apply-baselines.sh --dry-run
./apply-baselines.sh
./apply-baselines.sh zshrc
./apply-baselines.sh zsh/env.zsh
```

The script makes backups before overwriting anything unless `--no-backup` is used.

## Local AI backends

This setup exposes a small local-provider layer on top of the existing `llama.cpp` helpers.

Core env vars:

- `LOCAL_AI_PROVIDER`: current backend, either `llama.cpp` or `lmstudio`
- `LOCAL_AI_PROVIDER_URL`: OpenAI-compatible local base URL
- `LOCAL_AI_API_KEY`: local auth token, usually `local` unless LM Studio auth is enabled
- `LOCAL_AI_MODEL`: model identifier for the active backend
- `LOCAL_AI_CONTEXT_LENGTH`: context length matched to the current machine profile
- `LOCAL_AI_ENABLE_THINKING`: shared chat-template thinking toggle for Qwen/Gemma hybrid reasoning models
- `LOCAL_AI_PRESERVE_THINKING`: Qwen 3.6 reasoning-context preservation toggle used when thinking mode is enabled
- `LOCAL_AI_RECOMMENDATIONS_SOURCE`: recommendation metadata source, defaults to `hf` and falls back to local-only if disabled
- `LOCAL_AI_HF_CACHE_TTL_SECONDS`: cache TTL for Hugging Face model-info lookups used by `llama-recommendations`
- `LOCAL_AI_DISCOVERY_AUTHOR`: Hugging Face author namespace used by `llama-discover-models`, defaults to `unsloth`
- `LOCAL_AI_DISCOVERY_LIMIT`: number of Hugging Face repos to scan during discovery, defaults to `24`
- `LOCAL_AI_DISCOVERY_SEARCH`: Hugging Face search term used for discovery, defaults to `GGUF`
- `LOCAL_AI_CUSTOM_CATALOG_FILE`: optional custom TSV catalog that extends the built-in curated model list
- `LOCAL_AI_PRESET_OVERRIDES_FILE`: runtime TSV file used by `llama-curated-promote` for per-profile preset overrides
- `LLAMA_CPP_USE_TUNED_ARGS`: whether to apply cached benchmark-selected launch args automatically
- `LLAMA_CPP_AUTO_TUNE_ON_PULL`: whether newly downloaded model quants should be benchmarked automatically after a successful pull
- `LLAMA_CPP_AUTO_BENCH_VISION`: whether multimodal model pulls and candidate tests should also run the vision-path benchmark via `llama-mtmd-cli`, defaults to `true`
- `LOCAL_AI_BENCH_IMAGE`: optional path to a custom reference image used by the vision benchmark; when empty, a bundled 1x1 PNG is used

It also derives:

- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`

Useful commands:

```bash
local-ai-use llama.cpp
local-ai-use lmstudio
local-ai-status
local-ai-env
local-ai-load current
local-ai-load best
llama-thinking on
llama-thinking off
llama-thinking preserve-on
llama-switch qwen
llama-pull-recommended qwen
qwen27
llama-bench-preset vision
llama-bench-show vision
llama-bench-history vision
llama-bench-vision vision
llama-bench-vision-show vision
llama-keep-alive vision
llama-keep-alive-status
llama-keep-alive-stop
llama-recommendations
llama-recommendations all
llama-discover-models
llama-discover-models reasoning macbook-pro 12
llama-discover-models fits-16g
llama-pull-candidate unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF
llama-candidate-test unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF
llama-uninstall Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-UD-Q4_K_XL.gguf
llama-curated-add unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf "Qwen 3.6 35B Q4 XL"
llama-curated-list custom
llama-curated-promote macbook-pro best DeepSeek-R1-Distill-Qwen-14B-GGUF/DeepSeek-R1-Distill-Qwen-14B-UD-Q4_K_M.gguf
llama-curated-promotions
llama-recommend-quant fast
llama-pull-recommended best
llama-bench-compare multimodal
llama-bench-compare reasoning quality
```

Named presets such as `best`, `vision`, `balanced`, and `fast` are profile-aware and will auto-pull missing model assets for the chosen backend path before loading.

`llama-bench-preset <target> [auto|text|vision]` benchmarks a few local launch profiles for the resolved model, saves the best one under `LOCAL_AI_RUNTIME_DIR`, and `llama-start` will reuse that cached profile automatically unless `LLAMA_CPP_USE_TUNED_ARGS=false`. Tuned records are now keyed by machine profile, model, context size, mode, and current `llama.cpp` build so they do not bleed across very different setups.

When `LLAMA_CPP_AUTO_TUNE_ON_PULL=true`, a newly downloaded quant will also run through `llama-bench-preset` automatically once so it gets a cached launch profile immediately.

`llama-bench-history [target]` shows the recent benchmark winners that have been recorded for a model, including the launch args that were selected.

`llama-bench-vision [target]` benchmarks the real multimodal path. It calls `llama-mtmd-cli` with the model, its `mmproj` sibling, and the reference image from `LOCAL_AI_BENCH_IMAGE` (defaulting to a bundled 1x1 PNG), then parses `llama-mtmd-cli`'s timing output into `load_ms`, `image_encode_ms`, `prompt_tps`, and `gen_tps` and stores them in `bench-vision.tsv` under `LOCAL_AI_RUNTIME_DIR`. Unlike the text bench (which records `mode=vision` only as a label for tuning records), this one actually feeds an image through the projector, so the numbers reflect the cost users will see when the server runs with `--mmproj`. `llama-bench-vision-show [target]` prints the latest record. The vision bench runs automatically after a multimodal model is freshly pulled (guarded by `LLAMA_CPP_AUTO_BENCH_VISION`) and as part of `llama-candidate-test` when the candidate is classified as multimodal and ships an `mmproj`. `llama-bench-compare` will emit an additional `vision=` line under each model row when a vision record exists for it.

`llama-recommendations [current|all|mini|balanced|macbook-pro]` prints the curated hand-picked model matrix for each setup, including preset, quant, context, resolved GGUF path, and live Hugging Face repo metadata when `LOCAL_AI_RECOMMENDATIONS_SOURCE=hf`.

`llama-discover-models [other|all|reasoning|multimodal|general|fits-16g|fits-32g|fits-48g] [profile] [limit]` queries Hugging Face for additional GGUF candidates, classifies them, picks the most suitable quant for the requested profile, and scores likely machine fit. The output now includes estimated model size, multimodal readiness, exact relative model path, and a more precise catalog status: `curated`, `family-known`, or `new`.

`llama-curated-add <hf-repo> <gguf-file-or-relpath> [label] [family] [class] [scope]` appends a custom TSV entry to `LOCAL_AI_CUSTOM_CATALOG_FILE` so discoveries can graduate into your local curated list without editing the built-in catalog in the script. `llama-curated-list [all|custom]` shows the resulting catalog view.

`llama-pull-candidate <hf-repo> [gguf-file] [profile]` pulls a discovered candidate directly, auto-selecting a likely quant for the requested profile when no file is provided. If the repo is multimodal and exposes an `mmproj`, that projector is pulled too.

`llama-candidate-test <hf-repo> [gguf-file] [profile]` runs the full discovery workflow for a candidate: add to the custom catalog if needed, pull it, benchmark it, and then show the relevant compare table.

`llama-curated-promote <profile> <best|vision|balanced|fast> <model-target>` writes a runtime preset override into `LOCAL_AI_PRESET_OVERRIDES_FILE`, so discovered or custom-catalog models can become the active recommended preset for a given machine profile without editing the built-in mappings. `llama-curated-promotions` lists the current promoted overrides. `llama-recommendations` marks each preset row with `promoted=env` or `promoted=file` when an override is in effect, and `local-ai-status` shows how many promotions are active.

`llama-uninstall <rel> [--force]` removes a pulled model file, drops its `mmproj` sibling and Hugging Face cache metadata when no other GGUF remains in the repo directory, prunes matching rows from the benchmark profile and history files, and clears any `scope=candidate` custom-catalog entries. Curated (non-candidate) scopes and promotion overrides are only touched with `--force`.

`llama-bench-compare [class] [scope]` compares the latest locally recorded benchmark results for the curated models within the requested bucket. Useful examples are `llama-bench-compare multimodal`, `llama-bench-compare reasoning`, or `llama-bench-compare reasoning quality`.

Vision models also get a safer automatic retry path on startup if the first `llama-server` launch fails to become ready.

For projector files, the Gemma helpers now score any sibling `mmproj*.gguf` files using GGUF metadata when available and prefer the best match instead of assuming a single hard-coded filename.

`llama-keep-alive <target>` runs a lightweight supervisor loop for `llama.cpp` that restarts the selected model with backoff if the server drops during long local sessions. The loop state and logs are written under `LOCAL_AI_RUNTIME_DIR` and `LLAMA_CPP_LOGS`.

Preset mappings can be overridden per machine profile with env vars such as:

- `LOCAL_AI_PRESET_MAC_MINI_16G_BEST_MODEL`
- `LOCAL_AI_PRESET_MAC_MINI_16G_VISION_MODEL`
- `LOCAL_AI_PRESET_MAC_MINI_16G_BALANCED_MODEL`
- `LOCAL_AI_PRESET_MAC_MINI_16G_FAST_MODEL`
- `LOCAL_AI_PRESET_MACBOOK_PRO_48G_BEST_MODEL`
- `LOCAL_AI_PRESET_MACBOOK_PRO_48G_VISION_MODEL`

Each value should be a relative model path under `LLAMA_CPP_MODELS`.

Quant recommendations are also profile-aware. `llama-recommend-quant <target>` prints the suggested quant for the active machine profile, and `llama-pull-recommended <target>` downloads the corresponding model directly.

`qwen` now resolves to the profile-aware Qwen 3.6 `35B-A3B` GGUF, while `qwen27` still points to the older Qwen 3.5 27B helper. The current Qwen 3.6 defaults are:

- thinking mode: `temperature=0.6`, `top_p=0.95`, `top_k=20`, `presence_penalty=0.0`, `preserve_thinking=true`
- non-thinking mode: `temperature=0.7`, `top_p=0.8`, `top_k=20`, `presence_penalty=1.5`

Qwen 3.6 also uses a separate `LLAMA_CPP_QWEN_CTX_SIZE` so its local context defaults can be tuned independently from Gemma.

LM Studio can reuse the GGUF files already stored under `LLAMA_CPP_MODELS`:

```bash
lmstudio-import-llama-model gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf
lmstudio-import-llama-all
lmstudio-list-imported
```

Imports use `lms import --symbolic-link`, so LM Studio points at the same files instead of copying them.

For multimodal `GGUF + mmproj` models, the import helpers run an LM Studio validation pass. If LM Studio cannot load that imported layout successfully, the model is marked as `llama.cpp`-preferred and should stay on the direct `llama.cpp` path.

## Notes

This setup is pretty personal, so a few paths assume my machine layout, including:

- Apple Silicon Homebrew at `/opt/homebrew`
- extra storage mounted at `/Volumes/WorkSSD`
- working directories rooted under `~/DevStorage`

If you copy stuff from here, you will probably want to swap a few paths around and delete whatever does not match your setup.
