#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./apply-baselines.sh [options] [baseline...]

Apply repo baselines to their target paths in $HOME.
Repo paths are mapped by making the first path segment hidden in $HOME.
Examples:
  zshrc -> ~/.zshrc
  zsh/env.zsh -> ~/.zsh/env.zsh
  .config/starship.toml -> ~/.config/starship.toml

Options:
  -n, --dry-run    Show what would change without writing files
  --no-backup      Skip backup creation before replacing files
  -l, --list       List known baselines and exit
  -h, --help       Show this help message

Examples:
  ./apply-baselines.sh
  ./apply-baselines.sh --dry-run
  ./apply-baselines.sh zshrc
  ./apply-baselines.sh zsh/env.zsh
EOF
}

is_ignored_candidate() {
  local candidate="$1"
  local basename_candidate

  basename_candidate="$(basename "$candidate")"

  case "$candidate" in
    apply-baselines.sh|AGENTS.md|README|README.*|LICENSE|LICENSE.*|.gitignore|.gitattributes)
      return 0
      ;;
  esac

  case "$basename_candidate" in
    .DS_Store)
      return 0
      ;;
  esac

  return 1
}

collect_baselines() {
  local path
  local relative_path

  while IFS= read -r path; do
    relative_path="${path#"$SCRIPT_DIR"/}"
    if is_ignored_candidate "$relative_path"; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done < <(find "$SCRIPT_DIR" -type f ! -path "$SCRIPT_DIR/.git/*" | LC_ALL=C sort)
}

toggle_first_path_segment() {
  local candidate="$1"
  local first_segment
  local remainder=""

  first_segment="${candidate%%/*}"
  if [[ "$candidate" == */* ]]; then
    remainder="${candidate#*/}"
  fi

  if [[ "$first_segment" == .* ]]; then
    first_segment="${first_segment#.}"
  else
    first_segment=".$first_segment"
  fi

  if [[ -n "$remainder" ]] && [[ "$remainder" != "$candidate" ]]; then
    printf '%s/%s\n' "$first_segment" "$remainder"
  else
    printf '%s\n' "$first_segment"
  fi
}

resolve_baseline_name() {
  local candidate="$1"
  local alternate

  if [[ -f "$SCRIPT_DIR/$candidate" ]] && ! is_ignored_candidate "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  alternate="$(toggle_first_path_segment "$candidate")"
  if [[ -f "$SCRIPT_DIR/$alternate" ]] && ! is_ignored_candidate "$alternate"; then
    printf '%s\n' "$alternate"
    return 0
  fi

  return 1
}

destination_for() {
  local baseline="$1"
  local first_segment
  local remainder=""

  first_segment="${baseline%%/*}"
  if [[ "$baseline" == */* ]]; then
    remainder="${baseline#*/}"
  fi

  if [[ "$first_segment" != .* ]]; then
    first_segment=".$first_segment"
  fi

  if [[ -n "$remainder" ]] && [[ "$remainder" != "$baseline" ]]; then
    printf '%s/%s/%s\n' "$HOME" "$first_segment" "$remainder"
  else
    printf '%s/%s\n' "$HOME" "$first_segment"
  fi
}

source_for() {
  printf '%s/%s\n' "$SCRIPT_DIR" "$1"
}

print_known_baselines() {
  local baseline
  local destination

  while IFS= read -r baseline; do
    destination="$(destination_for "$baseline")"
    printf '%s -> %s\n' "$baseline" "$destination"
  done < <(collect_baselines)
}

ensure_parent_dir() {
  local destination="$1"
  mkdir -p "$(dirname "$destination")"
}

backup_path_for() {
  local destination="$1"
  local backup_root="$2"
  local relative_path

  relative_path="${destination#"$HOME"/}"
  relative_path="${relative_path#/}"

  if [[ -z "$relative_path" ]] || [[ "$relative_path" == "$destination" ]]; then
    relative_path="$(basename "$destination")"
  fi

  printf '%s/%s\n' "$backup_root" "$relative_path"
}

copy_file() {
  local source="$1"
  local destination="$2"
  cp "$source" "$destination"
}

apply_one() {
  local baseline="$1"
  local source="$2"
  local destination="$3"
  local dry_run="$4"
  local no_backup="$5"
  local backup_root="$6"
  local backup_path=""

  if [[ ! -f "$source" ]]; then
    printf 'Missing baseline source: %s\n' "$source" >&2
    return 1
  fi

  if [[ -d "$destination" ]]; then
    printf 'Refusing to overwrite directory: %s\n' "$destination" >&2
    return 1
  fi

  if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
    printf 'Unchanged %s (%s)\n' "$baseline" "$destination"
    return 0
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    if [[ -e "$destination" ]] && [[ "$no_backup" -ne 1 ]]; then
      backup_path="$(backup_path_for "$destination" "$backup_root")"
      printf 'Would back up %s -> %s\n' "$destination" "$backup_path"
    fi
    printf 'Would apply %s -> %s\n' "$source" "$destination"
    return 0
  fi

  ensure_parent_dir "$destination"

  if [[ -e "$destination" ]] && [[ "$no_backup" -ne 1 ]]; then
    mkdir -p "$backup_root"
    backup_path="$(backup_path_for "$destination" "$backup_root")"
    mkdir -p "$(dirname "$backup_path")"
    cp -a "$destination" "$backup_path"
    printf 'Backed up %s -> %s\n' "$destination" "$backup_path"
  fi

  copy_file "$source" "$destination"
  printf 'Applied %s -> %s\n' "$baseline" "$destination"
}

main() {
  local dry_run=0
  local no_backup=0
  local arg
  local baseline
  local resolved_baseline
  local source
  local destination
  local backup_root
  local -a requested=()

  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      -n|--dry-run)
        dry_run=1
        ;;
      --no-backup)
        no_backup=1
        ;;
      -l|--list)
        print_known_baselines
        return 0
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        requested+=("$arg")
        ;;
    esac
    shift
  done

  if [[ "${#requested[@]}" -eq 0 ]]; then
    while IFS= read -r baseline; do
      requested+=("$baseline")
    done < <(collect_baselines)
  fi

  if [[ "${#requested[@]}" -eq 0 ]]; then
    printf 'No baselines found in %s\n' "$SCRIPT_DIR" >&2
    return 1
  fi

  for arg in "${requested[@]}"; do
    if ! resolved_baseline="$(resolve_baseline_name "$arg")"; then
      printf 'Unknown baseline: %s\n' "$arg" >&2
      printf 'Known baselines:\n' >&2
      print_known_baselines >&2
      return 1
    fi
  done

  backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

  for arg in "${requested[@]}"; do
    resolved_baseline="$(resolve_baseline_name "$arg")"
    source="$(source_for "$resolved_baseline")"
    destination="$(destination_for "$resolved_baseline")"
    apply_one "$resolved_baseline" "$source" "$destination" "$dry_run" "$no_backup" "$backup_root"
  done
}

main "$@"
