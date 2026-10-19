#!/usr/bin/env bash
# Orchestration/safety checks only: mock tools do NOT produce cursor binaries.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
mkdir -p -- "$source_dir/build"
run=$(mktemp -d "$source_dir/build/test-XXXXXXXX")
printf 'TEST DOUBLES ONLY. No real PNGs or Xcursor binaries.\n' > "$run/TEST-ONLY.txt"
mkdir -- "$run/mock-tools" "$run/missing-tools"
fail() { printf 'FAIL: %s\nArtifacts: %s\n' "$*" "$run" >&2; exit 1; }
expect_failure() {
    if "$@" > "$run/last-error.log" 2>&1; then fail 'Command unexpectedly succeeded'; fi
}
cat > "$run/mock-tools/rsvg-convert" <<'MOCK'
#!/bin/bash
set -euo pipefail
[[ ${FAIL_RENDER:-0} != 1 ]] || exit 17
output= width= height= input=
for arg in "$@"; do
    case $arg in
        --output=*) output=${arg#*=} ;;
        --width=*) width=${arg#*=} ;;
        --height=*) height=${arg#*=} ;;
        --format=png) ;;
        --*) exit 18 ;;
        *) input=$arg ;;
    esac
done
[[ -f $input && -n $output && $width == "$height" ]] || exit 19
printf 'MOCK PNG %s %s\n' "$width" "${input##*/}" > "$output"
MOCK
cat > "$run/mock-tools/xcursorgen" <<'MOCK'
#!/bin/bash
set -euo pipefail
while read -r size hx hy png delay extra; do
    [[ -z $extra && -f $png ]] || exit 20
    (( hx >= 0 && hy >= 0 && hx < size && hy < size )) || exit 21
    read -r mock kind width input < "$png"
    [[ $mock == MOCK && $kind == PNG && $width == "$size" ]] || exit 22
done < "$1"
# A config copy, deliberately NOT an Xcursor binary.
cp -- "$1" "$2"
MOCK
cat > "$run/missing-tools/dirname" <<'MOCK'
#!/bin/bash
exec /usr/bin/dirname "$@"
MOCK
chmod +x "$run/mock-tools/"* "$run/missing-tools/dirname"
test_path="$run/mock-tools:$PATH"

PATH="$test_path" "$BASH" "$source_dir/build.sh" --help > "$run/help.log"
expect_failure env PATH="$test_path" "$BASH" "$source_dir/build.sh" one two
expect_failure env PATH="$test_path" "$BASH" "$source_dir/build.sh" ''

mkdir -- "$run/existing output"
printf 'PRESERVE\n' > "$run/existing output/sentinel"
expect_failure env PATH="$test_path" "$BASH" "$source_dir/build.sh" "$run/existing output"
[[ $(cat "$run/existing output/sentinel") == PRESERVE ]] || fail 'Existing directory changed'
[[ $(find "$run/existing output" -type f | wc -l) -eq 1 ]] || fail 'Existing directory received files'
expect_failure env PATH="$test_path" "$BASH" "$source_dir/build.sh" "$run/existing output/sentinel"
expect_failure env PATH="$run/missing-tools" "$BASH" "$source_dir/build.sh" "$run/missing output"
grep -q 'Missing tool: rsvg-convert' "$run/last-error.log" || fail 'Missing-tool diagnostic'
[[ ! -e "$run/missing output" ]] || fail 'Missing tools created output'

output="$run/output with spaces/index-needle"
PATH="$test_path" "$BASH" "$source_dir/build.sh" "$output" > "$run/build.log"
cmp "$source_dir/index.theme" "$output/index.theme"
[[ $(find "$output/.build" -name '*.png' | wc -l) -eq 84 ]] || fail 'Expected 84 renders'
[[ $(find "$output/.build" -name '*.cursor' | wc -l) -eq 14 ]] || fail 'Expected 14 canonical roles'
while read -r role hx hy delay frame_list; do
    [[ -z $role || $role == \#* ]] && continue
    read -r -a frames <<< "$frame_list"
    expected="$run/expected-$role.cursor"
    : > "$expected"
    # Fixed expected coordinates independently check the scaling rule.
    for size in 24 32 48; do
        case "$role:$size" in
            default:24|progress:24) x=2; y=2 ;;
            default:32|progress:32) x=3; y=3 ;;
            default:48|progress:48) x=5; y=5 ;;
            link:24) x=10; y=2 ;;
            link:32) x=13; y=3 ;;
            link:48) x=20; y=5 ;;
            *:24) x=12; y=12 ;;
            *:32) x=16; y=16 ;;
            *:48) x=24; y=24 ;;
        esac
        for frame in "${frames[@]}"; do
            printf '%s %s %s %s-%s.png %s\n' "$size" "$x" "$y" "${frame%.svg}" "$size" "$delay" >> "$expected"
        done
    done
    cmp "$expected" "$output/.build/$role.cursor" || fail "Config mismatch: $role"
    cmp "$expected" "$output/cursors/$role" || fail "Compiler input mismatch: $role"
done < "$source_dir/roles.tsv"
while read -r alias target extra; do
    [[ -z $alias || $alias == \#* ]] && continue
    [[ -e $output/cursors/$alias ]] || fail "Dangling alias: $alias"
    if [[ -L $output/cursors/$alias ]]; then
        [[ $(readlink "$output/cursors/$alias") == "$target" ]] || fail "Alias is not a direct relative link: $alias"
    else
        # MSYS can emulate symlinks by copying; real Linux must use symlinks.
        case $(uname -s) in MINGW*|MSYS*) ;; *) fail "Alias is not a symlink: $alias" ;; esac
    fi
    cmp "$output/cursors/$alias" "$output/cursors/$target" || fail "Wrong alias content: $alias"
done < "$source_dir/aliases.tsv"
expect_failure env PATH="$test_path" "$BASH" "$source_dir/build.sh" "$output"
expect_failure env PATH="$test_path" FAIL_RENDER=1 "$BASH" "$source_dir/build.sh" "$run/render failure"
[[ ! -e "$run/render failure/cursors/default" ]] || fail 'Render failure emitted a cursor'

# Check default destination in a private fixture, leaving the real source alone.
fixture="$run/default fixture"
mkdir -- "$fixture"
cp -- "$source_dir/build.sh" "$source_dir/index.theme" "$source_dir/roles.tsv" "$source_dir/aliases.tsv" "$fixture/"
cp -R -- "$source_dir/src" "$fixture/src"
(cd -- "$run" && PATH="$test_path" "$BASH" "$fixture/build.sh") > "$run/default.log"
[[ -f $fixture/build/index-needle/index.theme ]] || fail 'Default output path'
printf 'PASS: 14 roles, 84 renders, scaled hotspots, animations, aliases, path spaces, default output, refusal/failure cases.\n'
printf 'Mock-tool artifacts retained under: %s\n' "$run"
printf 'Real rsvg-convert / xcursorgen build remains a separate verification.\n'
