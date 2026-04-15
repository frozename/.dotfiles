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
- `LLAMA_CPP_USE_TUNED_ARGS`: whether to apply cached benchmark-selected launch args automatically
- `LLAMA_CPP_AUTO_TUNE_ON_PULL`: whether newly downloaded model quants should be benchmarked automatically after a successful pull

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
llama-bench-preset vision
llama-bench-show vision
llama-bench-history vision
llama-keep-alive vision
llama-keep-alive-status
llama-keep-alive-stop
llama-recommend-quant fast
llama-pull-recommended best
```

Named presets such as `best`, `vision`, `balanced`, and `fast` are profile-aware and will auto-pull missing model assets for the chosen backend path before loading.

`llama-bench-preset <target>` benchmarks a few local launch profiles for the resolved model, saves the best one under `LOCAL_AI_RUNTIME_DIR`, and `llama-start` will reuse that cached profile automatically unless `LLAMA_CPP_USE_TUNED_ARGS=false`.

When `LLAMA_CPP_AUTO_TUNE_ON_PULL=true`, a newly downloaded quant will also run through `llama-bench-preset` automatically once so it gets a cached launch profile immediately.

`llama-bench-history [target]` shows the recent benchmark winners that have been recorded for a model, including the launch args that were selected.

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
