# =========================================================
# BUN / NODE
# =========================================================

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
  fnm use --silent-if-unchanged default >/dev/null 2>&1 || true

  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
  fi
fi

bum-status() {
  echo "Bum binary: $(command -v bum 2>/dev/null || echo 'not found')"
  echo "Bun binary: $(command -v bun 2>/dev/null || echo 'not found')"
  echo "Bum version: $(bum --version 2>/dev/null || echo 'unknown')"
  echo "Bun version: $(bun --version 2>/dev/null || echo 'unknown')"
  echo

  if [ -f .bumrc ]; then
    echo ".bumrc: $(cat .bumrc)"
  else
    echo ".bumrc: not present"
  fi
}

alias bi='bun install'
alias br='bun run'
alias bx='bunx'
alias bt='bun test'
alias bdev='bun run dev'
alias bbuild='bun run build'

bmu() {
  if [ -z "$1" ]; then
    echo "Usage: bmu <version>"
    return 1
  fi

  bum use "$1"
  bun --version
}

bmset() {
  if [ -z "$1" ]; then
    echo "Usage: bmset <version>"
    return 1
  fi

  printf "%s\n" "$1" > .bumrc
  echo "Wrote .bumrc -> $1"
  bum use "$1"
}

bmuse() {
  if [ ! -f .bumrc ]; then
    echo "No .bumrc found in current directory"
    return 1
  fi

  bum use
  bun --version
}

bmrm() {
  if [ -z "$1" ]; then
    echo "Usage: bmrm <version>"
    return 1
  fi

  bum remove "$1"
}

bmsearch() {
  if [ -n "$1" ]; then
    bum list-remote | grep -i "$1"
  else
    bum list-remote
  fi
}

bm-auto-use() {
  if [ -f .bumrc ]; then
    local target
    target="$(cat .bumrc 2>/dev/null)"

    if [ -n "$target" ]; then
      local current
      current="$(bun --version 2>/dev/null)"

      if [ "$current" != "$target" ]; then
        echo "Switching Bun version via .bumrc -> $target"
        bum use "$target" >/dev/null && bun --version
      fi
    fi
  fi
}

if [ -n "$ZSH_VERSION" ]; then
  autoload -U add-zsh-hook 2>/dev/null
  add-zsh-hook chpwd bm-auto-use 2>/dev/null
fi

if [ -n "$BASH_VERSION" ]; then
  case ";$PROMPT_COMMAND;" in
    *";bm-auto-use;"*) ;;
    *)
      PROMPT_COMMAND="bm-auto-use${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
      ;;
  esac
fi

[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
