#!/usr/bin/env bash
# Optional user themes; no package installation or desktop/session changes.
# Usage: bash tools/install-extras.sh [--components terminals,fastfetch] [--restore]
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
IDX="$DATA/index"
BACKUPS="$IDX/extras-backups"
components=terminals,fastfetch
restore=0
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }
usage() {
    printf '%s\n' 'Usage: bash tools/install-extras.sh [--components terminals,fastfetch] [--restore]' \
        'Default: both components. Run as your normal user; no sudo or package installation.' \
        'Terminals requires kwriteconfig6. Restore needs no KDE tools.'
}
while (($#)); do
    case "$1" in
        --components)
            (($# >= 2)) || die '--components requires a comma-separated list'
            components=$2; shift 2 ;;
        --restore) restore=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
[[ $(id -u) != 0 ]] || die 'Run as your normal user, not root.'
[[ -n $components && $components != ,* && $components != *, && $components != *,,* ]] || die 'Empty component name'
IFS=, read -r -a selected <<< "$components"
for component in "${selected[@]}"; do
    case "$component" in terminals|fastfetch) ;; *) die "Unknown component: $component" ;; esac
done

# Keep JSON/TOML basic strings valid even with quotes or backslashes in XDG paths.
quote_path() {
    local value=$1
    value=${value//\\/\\\\}; value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}; value=${value//$'\r'/\\r}; value=${value//$'\t'/\\t}
    printf '"%s"' "$value"
}

shopt -s nullglob
fonts=("$SRC/assets/PerfectDOSVGA437-Universal.ttf")
if (( ! restore )); then
    # Check all selected inputs before backing up or changing anything.
    for component in "${selected[@]}"; do
        case "$component" in
            terminals)
                command -v kwriteconfig6 >/dev/null || die 'Terminals needs kwriteconfig6 (kconfig).'
                [[ -f ${fonts[0]} ]] || die 'Missing canonical INDEX Universal font in assets/'
                inputs=("$SRC/kde/konsole/INDEX.colorscheme" "$SRC/kde/konsole/INDEX.profile" "$SRC/kde/alacritty/index.toml") ;;
            fastfetch) inputs=("$SRC/fastfetch/config.jsonc" "$SRC/fastfetch/index.txt") ;;
        esac
        for file in "${inputs[@]}"; do [[ -f $file ]] || die "Missing source: $file"; done
    done
fi

# Snapshot paths are relative to config/ or data/, never to the source tree.
# Existing install.sh backups are read only, including the legacy Fastfetch one.
snapshot_file() {
    local base=$1 relative=$2 root legacy="$IDX/fastfetch-before-index"
    case "$base" in config) root=$CFG ;; data) root=$DATA ;; esac
    # Also cover newly added font assets on upgrades, without replacing originals.
    if grep -qxF "$base/$relative" "$snapshot/files.txt" 2>/dev/null; then return 0; fi
    printf '%s/%s\n' "$base" "$relative" >> "$snapshot/files.txt"
    mkdir -p "$snapshot/$base/$(dirname "$relative")"
    if [[ $component == fastfetch && -f $legacy/${relative##*/} ]]; then
        cp -p "$legacy/${relative##*/}" "$snapshot/$base/$relative"
    elif [[ $component == fastfetch ]] && grep -qxF "${relative##*/}" "$legacy/absent.txt" 2>/dev/null; then
        printf '%s/%s\n' "$base" "$relative" >> "$snapshot/absent.txt"
    elif [[ -f $root/$relative || -L $root/$relative ]]; then
        cp -a "$root/$relative" "$snapshot/$base/$relative"
    elif [[ -e $root/$relative ]]; then
        die "Expected a file: $root/$relative"
    else
        printf '%s/%s\n' "$base" "$relative" >> "$snapshot/absent.txt"
    fi
}
snapshot_component() {
    local snapshot="$BACKUPS/$component" font
    mkdir -p "$snapshot"
    if [[ ! -f $snapshot/ready ]]; then
        : > "$snapshot/files.txt"
        : > "$snapshot/absent.txt"
    fi
    case "$component" in
        terminals)
            snapshot_file config konsolerc
            snapshot_file config alacritty/alacritty.toml
            snapshot_file config alacritty/alacritty.user.toml
            snapshot_file config alacritty/index.toml
            snapshot_file data konsole/INDEX.colorscheme
            snapshot_file data konsole/INDEX.profile
            for font in "${fonts[@]}"; do snapshot_file data "fonts/index/${font##*/}"; done ;;
        fastfetch)
            snapshot_file config fastfetch/config.jsonc
            snapshot_file config fastfetch/index.txt ;;
    esac
    touch "$snapshot/ready"
}
restore_component() {
    local snapshot="$BACKUPS/$component" path root relative
    if [[ ! -f $snapshot/installed ]]; then info "$component: nothing installed by this helper"; return 0; fi
    while IFS= read -r path; do
        relative=${path#*/}
        case "$path" in config/*) root=$CFG ;; data/*) root=$DATA ;; esac
        if [[ -f $snapshot/$path || -L $snapshot/$path ]]; then
            mkdir -p "$root/$(dirname "$relative")"
            # Replace the file itself, including a symlink, rather than its target.
            rm -f "$root/$relative"
            cp -a "$snapshot/$path" "$root/$relative"
        elif grep -qxF "$path" "$snapshot/absent.txt"; then
            if [[ $path == config/alacritty/alacritty.user.toml && ! -f $snapshot/created-alacritty-user ]]; then
                continue
            fi
            rm -f "$root/$relative"
        fi
    done < "$snapshot/files.txt"
    rm -f "$snapshot/installed" "$snapshot/created-alacritty-user"
    info "$component restored (original snapshot kept)"
}
install_terminals() {
    local ala="$CFG/alacritty/alacritty.toml" user="$CFG/alacritty/alacritty.user.toml" imports
    mkdir -p "$DATA/fonts/index" "$DATA/konsole" "$CFG/alacritty"
    cp -f "${fonts[@]}" "$DATA/fonts/index/"
    cp -f "$SRC/kde/konsole/INDEX.colorscheme" "$SRC/kde/konsole/INDEX.profile" "$DATA/konsole/"
    cp -f "$SRC/kde/alacritty/index.toml" "$CFG/alacritty/index.toml"
    # The theme must be imported last: keys in the main file override imports.
    if [[ -f $ala ]] && ! grep -q '^# THE INDEX' "$ala"; then
        if [[ ! -e $user && ! -L $user ]]; then touch "$BACKUPS/terminals/created-alacritty-user"; fi
        mv -f "$ala" "$user"
        if command -v alacritty >/dev/null; then
            alacritty migrate --config-file "$user" --skip-imports --silent >/dev/null 2>&1 || true
        fi
    fi
    imports="$(quote_path "$CFG/alacritty/index.toml")"
    [[ ! -f $user ]] || imports="$(quote_path "$user"), $imports"
    printf '# THE INDEX: your settings first, then the INDEX theme on top\n[general]\nimport = [%s]\n' "$imports" > "$ala"
    kwriteconfig6 --file "$CFG/konsolerc" --group 'Desktop Entry' --key DefaultProfile INDEX.profile
}
install_fastfetch() {
    local config logo
    mkdir -p "$CFG/fastfetch"
    config=$(cat "$SRC/fastfetch/config.jsonc")
    logo=$(quote_path "$CFG/fastfetch/index.txt")
    printf '%s\n' "${config//\"~\/.config\/fastfetch\/index.txt\"/"$logo"}" > "$CFG/fastfetch/config.jsonc"
    { printf '\033[38;2;93;173;226m'; cat "$SRC/fastfetch/index.txt"; printf '\033[0m\n'; } > "$CFG/fastfetch/index.txt"
}

for component in "${selected[@]}"; do
    if (( restore )); then
        restore_component
    else
        snapshot_component
        # Mark before writes so a failed or interrupted install can be restored.
        touch "$BACKUPS/$component/installed"
        "install_$component"
        info "$component installed"
    fi
done
if [[ ,$components, == *,terminals,* ]]; then
    fc-cache -f >/dev/null 2>&1 || info 'fc-cache unavailable or failed (ignored)'
fi
