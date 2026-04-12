# =========================================================
# REPOS
# =========================================================

_repo_select_from_base() {
  local base="$1"
  local query="${2:-}"
  local open_code="${3:-0}"
  local selected
  local -a matches

  [ -d "$base" ] || {
    echo "repo base not found: $base"
    return 1
  }

  if [ -n "$query" ]; then
    matches=("${(@f)$(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s#$base/##" | grep -i -- "$query" | sort)}")
  else
    matches=("${(@f)$(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s#$base/##" | sort)}")
  fi

  case "${#matches[@]}" in
    0)
      echo "no repo match found"
      return 1
      ;;
    1)
      selected="${matches[1]}"
      ;;
    *)
      if ! command -v fzf >/dev/null 2>&1; then
        echo "multiple matches found, but fzf is not installed"
        printf '%s\n' "${matches[@]}"
        return 1
      fi

      selected="$(
        printf '%s\n' "${matches[@]}" | \
          fzf \
            --height 50% \
            --layout=reverse \
            --border \
            --prompt="repo > " \
            --query="$query" \
            --preview 'eza -lah --icons --group-directories-first "'"$base"'"/{} 2>/dev/null || ls -lah "'"$base"'"/{}'
      )" || return 1
      ;;
  esac

  cd "$base/$selected" || return 1

  if [ "$open_code" = "1" ]; then
    code .
  fi
}

workrepo() {
  local query="${1:-}"
  _repo_select_from_base "$DEV_STORAGE/repos/work" "$query" 0
}

persrepo() {
  local query="${1:-}"
  _repo_select_from_base "$DEV_STORAGE/repos/personal" "$query" 0
}

mkworkrepo() {
  local name="$1"
  [ -n "$name" ] || { echo "usage: mkworkrepo <repo>"; return 1; }
  mkdir -p "$DEV_STORAGE/repos/work/$name" &&
    cd "$DEV_STORAGE/repos/work/$name" &&
    git init &&
    code .
}

mkpersrepo() {
  local name="$1"
  [ -n "$name" ] || { echo "usage: mkpersrepo <repo>"; return 1; }
  mkdir -p "$DEV_STORAGE/repos/personal/$name" &&
    cd "$DEV_STORAGE/repos/personal/$name" &&
    git init &&
    code .
}

reposfind() {
  find "$DEV_STORAGE/repos" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | \
    sed "s#$DEV_STORAGE/repos/##" | \
    sort
}

repo() {
  local query=""
  local open_code=0
  local selected
  local -a matches
  local base="$DEV_STORAGE/repos"

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  [ -d "$base" ] || {
    echo "repo base not found: $base"
    return 1
  }

  if [ -n "$query" ]; then
    matches=("${(@f)$(find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#$base/##" | grep -i -- "$query" | sort)}")
  else
    matches=("${(@f)$(find "$base" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#$base/##" | sort)}")
  fi

  case "${#matches[@]}" in
    0)
      echo "no repo match found"
      return 1
      ;;
    1)
      selected="${matches[1]}"
      ;;
    *)
      if ! command -v fzf >/dev/null 2>&1; then
        echo "multiple matches found, but fzf is not installed"
        printf '%s\n' "${matches[@]}"
        return 1
      fi

      selected="$(
        printf '%s\n' "${matches[@]}" | \
          fzf \
            --height 50% \
            --layout=reverse \
            --border \
            --prompt="repo > " \
            --query="$query" \
            --preview 'eza -lah --icons --group-directories-first "'"$base"'"/{} 2>/dev/null || ls -lah "'"$base"'"/{}'
      )" || return 1
      ;;
  esac

  cd "$base/$selected" || return 1

  if [ "$open_code" = "1" ]; then
    code .
  fi
}

repo-work() {
  local query=""
  local open_code=0

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  _repo_select_from_base "$DEV_STORAGE/repos/work" "$query" "$open_code"
}

repo-personal() {
  local query=""
  local open_code=0

  for arg in "$@"; do
    case "$arg" in
      --code)
        open_code=1
        ;;
      *)
        if [ -z "$query" ]; then
          query="$arg"
        else
          query="$query $arg"
        fi
        ;;
    esac
  done

  _repo_select_from_base "$DEV_STORAGE/repos/personal" "$query" "$open_code"
}

repo-code() {
  repo --code "$@"
}

repo-root() {
  git rev-parse --show-toplevel 2>/dev/null
}

alias wr="workrepo"
alias prj="persrepo"
alias mkwr="mkworkrepo"
alias mkprj="mkpersrepo"
alias rls="reposfind"
alias rf="repo"
alias rfw="repo-work"
alias rfp="repo-personal"
alias rc="repo-code"
