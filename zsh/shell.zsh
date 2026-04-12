# =========================================================
# SHELL
# =========================================================

setopt NO_BANG_HIST

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

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/.zcompcache"
