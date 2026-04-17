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
- `zsh/llm.zsh`: shim that sources [llamactl](https://github.com/frozename/llamactl) when present, for local Ollama and `llama.cpp` helpers
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

The local LLM helpers that used to live in `zsh/llm.zsh` now ship as a standalone project: [frozename/llamactl](https://github.com/frozename/llamactl). This dotfiles tree keeps a small shim that sources it when the clone is present. The convention is to clone llamactl to `$DEV_STORAGE/repos/personal/llamactl`; override with `$LLAMACTL_HOME` to point elsewhere.

```bash
git clone https://github.com/frozename/llamactl.git \
  "$DEV_STORAGE/repos/personal/llamactl"
```

Everything documented below (env vars, commands, benches, presets) lives in that repo's README now. When llamactl is not installed the dotfiles setup silently skips it and the rest of the shell works unchanged.

## Notes

This setup is pretty personal, so a few paths assume my machine layout, including:

- Apple Silicon Homebrew at `/opt/homebrew`
- extra storage mounted at `/Volumes/WorkSSD`
- working directories rooted under `~/DevStorage`

If you copy stuff from here, you will probably want to swap a few paths around and delete whatever does not match your setup.
