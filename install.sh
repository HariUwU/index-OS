#!/usr/bin/env bash
# Run as your normal user: bash install.sh
set -euo pipefail

INSTALLER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(id -u)" -eq 0 ]; then
    printf 'Run: bash install.sh\nUse your normal user; setup requests sudo when needed.\n' >&2
    exit 1
fi
if [ ! -f "$INSTALLER_DIR/new/setup.sh" ]; then
    printf 'Keep install.sh with the extracted new/ folder, then run it again.\n' >&2
    exit 1
fi
exec bash "$INSTALLER_DIR/new/setup.sh" "$@"
