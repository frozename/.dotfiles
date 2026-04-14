#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(
  CDPATH= cd "$(dirname "$0")" && pwd
)

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
  ignored_candidate=$1
  ignored_basename=$(basename "$ignored_candidate")

  case "$ignored_candidate" in
    apply-baselines.sh|AGENTS.md|README|README.*|LICENSE|LICENSE.*|.gitignore|.gitattributes)
      return 0
      ;;
  esac

  case "$ignored_basename" in
    .DS_Store)
      return 0
      ;;
  esac

  return 1
}

collect_baselines() {
  find "$SCRIPT_DIR" -type f ! -path "$SCRIPT_DIR/.git/*" | LC_ALL=C sort | while IFS= read -r collect_path; do
    collect_relative_path=${collect_path#"$SCRIPT_DIR"/}
    if is_ignored_candidate "$collect_relative_path"; then
      continue
    fi
    printf '%s\n' "$collect_relative_path"
  done
}

toggle_first_path_segment() {
  toggle_candidate=$1
  toggle_first_segment=${toggle_candidate%%/*}
  toggle_remainder=

  case "$toggle_candidate" in
    */*)
      toggle_remainder=${toggle_candidate#*/}
      ;;
  esac

  case "$toggle_first_segment" in
    .*)
      toggle_first_segment=${toggle_first_segment#.}
      ;;
    *)
      toggle_first_segment=.$toggle_first_segment
      ;;
  esac

  if [ -n "$toggle_remainder" ] && [ "$toggle_remainder" != "$toggle_candidate" ]; then
    printf '%s/%s\n' "$toggle_first_segment" "$toggle_remainder"
  else
    printf '%s\n' "$toggle_first_segment"
  fi
}

resolve_baseline_name() {
  resolve_candidate=$1

  if [ -f "$SCRIPT_DIR/$resolve_candidate" ] && ! is_ignored_candidate "$resolve_candidate"; then
    printf '%s\n' "$resolve_candidate"
    return 0
  fi

  resolve_alternate=$(toggle_first_path_segment "$resolve_candidate")
  if [ -f "$SCRIPT_DIR/$resolve_alternate" ] && ! is_ignored_candidate "$resolve_alternate"; then
    printf '%s\n' "$resolve_alternate"
    return 0
  fi

  return 1
}

destination_for() {
  destination_baseline=$1
  destination_first_segment=${destination_baseline%%/*}
  destination_remainder=

  case "$destination_baseline" in
    */*)
      destination_remainder=${destination_baseline#*/}
      ;;
  esac

  case "$destination_first_segment" in
    .*)
      ;;
    *)
      destination_first_segment=.$destination_first_segment
      ;;
  esac

  if [ -n "$destination_remainder" ] && [ "$destination_remainder" != "$destination_baseline" ]; then
    printf '%s/%s/%s\n' "$HOME" "$destination_first_segment" "$destination_remainder"
  else
    printf '%s/%s\n' "$HOME" "$destination_first_segment"
  fi
}

source_for() {
  printf '%s/%s\n' "$SCRIPT_DIR" "$1"
}

print_known_baselines() {
  collect_baselines | while IFS= read -r print_baseline; do
    print_destination=$(destination_for "$print_baseline")
    printf '%s -> %s\n' "$print_baseline" "$print_destination"
  done
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

backup_path_for() {
  backup_destination=$1
  backup_root=$2
  backup_relative_path=${backup_destination#"$HOME"/}
  backup_relative_path=${backup_relative_path#/}

  if [ -z "$backup_relative_path" ] || [ "$backup_relative_path" = "$backup_destination" ]; then
    backup_relative_path=$(basename "$backup_destination")
  fi

  printf '%s/%s\n' "$backup_root" "$backup_relative_path"
}

copy_file() {
  cp "$1" "$2"
}

apply_one() {
  apply_baseline=$1
  apply_source=$2
  apply_destination=$3
  apply_dry_run=$4
  apply_no_backup=$5
  apply_backup_root=$6

  if [ ! -f "$apply_source" ]; then
    printf 'Missing baseline source: %s\n' "$apply_source" >&2
    return 1
  fi

  if [ -d "$apply_destination" ]; then
    printf 'Refusing to overwrite directory: %s\n' "$apply_destination" >&2
    return 1
  fi

  if [ -f "$apply_destination" ] && cmp -s "$apply_source" "$apply_destination"; then
    printf 'Unchanged %s (%s)\n' "$apply_baseline" "$apply_destination"
    return 0
  fi

  if [ "$apply_dry_run" -eq 1 ]; then
    if [ -e "$apply_destination" ] && [ "$apply_no_backup" -ne 1 ]; then
      apply_backup_path=$(backup_path_for "$apply_destination" "$apply_backup_root")
      printf 'Would back up %s -> %s\n' "$apply_destination" "$apply_backup_path"
    fi
    printf 'Would apply %s -> %s\n' "$apply_source" "$apply_destination"
    return 0
  fi

  ensure_parent_dir "$apply_destination"

  if [ -e "$apply_destination" ] && [ "$apply_no_backup" -ne 1 ]; then
    mkdir -p "$apply_backup_root"
    apply_backup_path=$(backup_path_for "$apply_destination" "$apply_backup_root")
    mkdir -p "$(dirname "$apply_backup_path")"
    cp -p "$apply_destination" "$apply_backup_path"
    printf 'Backed up %s -> %s\n' "$apply_destination" "$apply_backup_path"
  fi

  copy_file "$apply_source" "$apply_destination"
  printf 'Applied %s -> %s\n' "$apply_baseline" "$apply_destination"
}

cleanup_temp_files() {
  if [ -n "${REQUESTED_FILE:-}" ] && [ -f "$REQUESTED_FILE" ]; then
    rm -f "$REQUESTED_FILE"
  fi

  if [ -n "${RESOLVED_FILE:-}" ] && [ -f "$RESOLVED_FILE" ]; then
    rm -f "$RESOLVED_FILE"
  fi
}

main() {
  dry_run=0
  no_backup=0

  REQUESTED_FILE=$(mktemp "${TMPDIR:-/tmp}/apply-baselines.requested.XXXXXX")
  RESOLVED_FILE=$(mktemp "${TMPDIR:-/tmp}/apply-baselines.resolved.XXXXXX")
  trap cleanup_temp_files EXIT INT TERM HUP

  while [ "$#" -gt 0 ]; do
    case "$1" in
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
        printf '%s\n' "$1" >> "$REQUESTED_FILE"
        ;;
    esac
    shift
  done

  if [ ! -s "$REQUESTED_FILE" ]; then
    collect_baselines > "$REQUESTED_FILE"
  fi

  if [ ! -s "$REQUESTED_FILE" ]; then
    printf 'No baselines found in %s\n' "$SCRIPT_DIR" >&2
    return 1
  fi

  while IFS= read -r main_arg; do
    if ! main_resolved_baseline=$(resolve_baseline_name "$main_arg"); then
      printf 'Unknown baseline: %s\n' "$main_arg" >&2
      printf 'Known baselines:\n' >&2
      print_known_baselines >&2
      return 1
    fi
    printf '%s\n' "$main_resolved_baseline" >> "$RESOLVED_FILE"
  done < "$REQUESTED_FILE"

  main_backup_root=$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)

  while IFS= read -r main_resolved_baseline; do
    main_source=$(source_for "$main_resolved_baseline")
    main_destination=$(destination_for "$main_resolved_baseline")
    apply_one "$main_resolved_baseline" "$main_source" "$main_destination" "$dry_run" "$no_backup" "$main_backup_root"
  done < "$RESOLVED_FILE"
}

main "$@"
