# =========================================================
# TOOLS
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

if command -v code-insiders >/dev/null 2>&1; then
  alias code="code-insiders"
fi

alias c="code"
alias c.="code ."

alias ..="cd .."
alias ...="cd ../.."

cw()   { cd "$DEV_STORAGE"; }
cwr()  { cd "$DEV_STORAGE/repos"; }
cww()  { cd "$DEV_STORAGE/repos/work"; }
cwp()  { cd "$DEV_STORAGE/repos/personal"; }
