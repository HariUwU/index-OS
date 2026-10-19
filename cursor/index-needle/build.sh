#!/usr/bin/env bash
# Build only. Never installs or activates a theme. Never removes output paths.
set -euo pipefail

die() { printf 'index-needle: %s\n' "$*" >&2; exit 1; }
usage() {
    printf 'Usage: bash build.sh [OUTPUT_THEME_DIRECTORY]\n'
    printf 'Default: <source>/build/index-needle (must not already exist).\n'
    printf 'Requires Bash 4+, rsvg-convert (librsvg), xcursorgen (xorg-xcursorgen).\n'
}
if [[ ${1-} == --help || ${1-} == -h ]]; then usage; exit 0; fi
(( $# <= 1 )) || die 'Expected at most one output directory.'
(( BASH_VERSINFO[0] >= 4 )) || die 'Bash 4 or newer is required.'
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
out=${1-"$source_dir/build/index-needle"}
[[ -n $out ]] || die 'Output directory cannot be empty.'
[[ ! -e $out && ! -L $out ]] || die "Refusing existing output: $out"
for tool in rsvg-convert xcursorgen; do
    command -v "$tool" >/dev/null 2>&1 || die "Missing tool: $tool. No theme was built."
done

# Validate every manifest row before creating the output directory.
declare -A roles=() aliases=()
name_pattern='^[a-zA-Z0-9][a-zA-Z0-9_-]*$'
while read -r role hx hy delay frame_list; do
    [[ -z $role || $role == \#* ]] && continue
    [[ $role =~ $name_pattern && -z ${roles[$role]+yes} ]] || die "Invalid/duplicate role: $role"
    [[ $hx =~ ^[0-9]+$ && $hy =~ ^[0-9]+$ && $delay =~ ^[0-9]+$ ]] || die "Invalid metadata: $role"
    (( hx < 32 && hy < 32 )) || die "Hotspot outside 32px viewBox: $role"
    read -r -a frames <<< "$frame_list"
    (( ${#frames[@]} > 0 )) || die "No frames: $role"
    (( ${#frames[@]} == 1 || delay > 0 )) || die "Animation needs a positive delay: $role"
    for frame in "${frames[@]}"; do
        [[ $frame =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*\.svg$ && -f $source_dir/src/$frame ]] || die "Missing/invalid SVG: $frame"
    done
    roles[$role]=1
done < "$source_dir/roles.tsv"
(( ${#roles[@]} > 0 )) || die 'No roles in manifest.'
while read -r alias target extra; do
    [[ -z $alias || $alias == \#* ]] && continue
    [[ $alias =~ $name_pattern && $target =~ $name_pattern && -z $extra ]] || die "Invalid alias: $alias"
    [[ -z ${roles[$alias]+yes} && -z ${aliases[$alias]+yes} ]] || die "Alias collision: $alias"
    [[ -n ${roles[$target]+yes} ]] || die "Unknown alias target: $target"
    aliases[$alias]=1
done < "$source_dir/aliases.tsv"

# mkdir (without -p on the final component) also refuses a concurrent creator.
# Keep all intermediates for inspection; no recursive cleanup, even on failure.
mkdir -p -- "$(dirname -- "$out")"
mkdir -- "$out"
out=$(cd -- "$out" && pwd -P)
mkdir -- "$out/cursors" "$out/.build"
cp -- "$source_dir/index.theme" "$out/index.theme"
while read -r role hx hy delay frame_list; do
    [[ -z $role || $role == \#* ]] && continue
    read -r -a frames <<< "$frame_list"
    config="$out/.build/$role.cursor"
    : > "$config"
    for size in 24 32 48; do
        # Round half up from the exact source coordinates, without float tools.
        xhot=$(( (hx * size + 16) / 32 ))
        yhot=$(( (hy * size + 16) / 32 ))
        for frame in "${frames[@]}"; do
            png="${frame%.svg}-$size.png"
            rsvg-convert --format=png --width="$size" --height="$size" \
                --output="$out/.build/$png" "$source_dir/src/$frame"
            # Relative PNG filenames keep xcursorgen configs safe with spaces.
            printf '%s %s %s %s %s\n' "$size" "$xhot" "$yhot" "$png" "$delay" >> "$config"
        done
    done
    (cd -- "$out/.build" && xcursorgen "$role.cursor" "../cursors/$role")
done < "$source_dir/roles.tsv"
while read -r alias target extra; do
    [[ -z $alias || $alias == \#* ]] && continue
    ln -s -- "$target" "$out/cursors/$alias"
done < "$source_dir/aliases.tsv"
printf 'Built INDEX Needle for review: %s\n' "$out"
printf '14 roles; sizes 24/32/48; eight-frame busy/progress at 80 ms per frame.\n'
printf 'No installation or activation performed. Intermediates: %s/.build\n' "$out"
