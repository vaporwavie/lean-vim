#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--path <nvim-config-path>]

Installs lean-vim into the given Neovim config directory.
Defaults to: ~/.config/nvim
EOF
}

REQUIRED_TOOLS=(
  nvim
  git
  fzf
  rg
  bat
  fd
  tree-sitter
  # LSP servers and formatters (e.g. via Homebrew); mason is not used
  lua-language-server
  vtsls
  biome
  tailwindcss-language-server
  stylua
  prettier
)

TARGET_DIR="$HOME/.config/nvim"

while (($# > 0)); do
  case "$1" in
    --path)
      if (($# < 2)); then
        print_usage
        exit 1
      fi
      TARGET_DIR="${2/#\~/$HOME}"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
done

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ Required tool missing: $tool"
    exit 1
  fi

done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"

canonical_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null && return 0
  fi

  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
    return 0
  fi

  local dir
  local base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ -d "$dir" ]]; then
    printf "%s/%s\n" "$(cd "$dir" && pwd -P)" "$base"
    return 0
  fi

  return 1
}

backup_if_needed() {
  local dir="$1"
  if [[ ! -e "$dir" ]]; then
    return 0
  fi

  if [[ ! -d "$dir" ]]; then
    echo "⚠️  Existing file found at $dir"
    echo "   Backing up to ${dir}.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$dir" "${dir}.backup.$(date +%Y%m%d-%H%M%S)"
    return 0
  fi

  if [[ -z "$(ls -A "$dir")" ]]; then
    rm -rf "$dir"
    return 0
  fi

  local backup_dir="${dir}.backup.$(date +%Y%m%d-%H%M%S)"
  echo "⚠️  Existing config found at $dir"
  echo "   Backing up to $backup_dir"
  mv "$dir" "$backup_dir"
}

TARGET_REAL="$(canonical_path "$TARGET_DIR" || true)"
if [[ -n "$TARGET_REAL" && "$TARGET_REAL" == "$REPO_ROOT" ]]; then
  echo "✅ lean-vim already lives at $TARGET_DIR"
  echo "Nothing to install."
  exit 0
fi

backup_if_needed "$TARGET_DIR"
mkdir -p "$(dirname "$TARGET_DIR")"
mkdir -p "$TARGET_DIR"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.git' "$REPO_ROOT/" "$TARGET_DIR/"
else
  cp -R "$REPO_ROOT/"/. "$TARGET_DIR/"
  rm -rf "$TARGET_DIR/.git"
fi

echo "✅ Installed lean-vim to $TARGET_DIR"
echo "Run: nvim"
