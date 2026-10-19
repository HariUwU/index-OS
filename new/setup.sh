#!/usr/bin/env bash
# Interactive setup, or --components desktop,fastfetch --dry-run for a preview.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo 'Install Python first: sudo pacman -S python' >&2; exit 1; }
exec python3 "$SRC/tools/setup.py" "$@"
