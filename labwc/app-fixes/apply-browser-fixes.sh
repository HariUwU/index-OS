#!/bin/sh
# WILL OF THE CITY :: THE INDEX — make browsers use ONLY the labwc titlebar.
DIR_SELF="$(cd "$(dirname "$0")" && pwd)"

# ---- Firefox family (Firefox, LibreWolf, Floorp) ----
for base in "$HOME/.mozilla/firefox" "$HOME/.librewolf" "$HOME/.floorp"; do
  [ -d "$base" ] || continue
  for prof in "$base"/*.default*/ "$base"/*.default-release/ "$base"/*/ ; do
    [ -d "$prof" ] || continue
    [ -f "${prof}prefs.js" ] || [ -f "${prof}times.json" ] || continue   # real profile
    cp -f "$DIR_SELF/firefox-user.js" "${prof}user.js" 2>/dev/null || true
  done
done

# ---- Chromium family (Chromium, Chrome, Brave, Vivaldi, Edge) ----
# set "custom_chrome_frame=false" -> use system (labwc) titlebar+border
for cfg in \
  "$HOME/.config/chromium" "$HOME/.config/google-chrome" \
  "$HOME/.config/BraveSoftware/Brave-Browser" \
  "$HOME/.config/vivaldi" "$HOME/.config/microsoft-edge"; do
  [ -d "$cfg" ] || continue
  PREF="$cfg/Default/Preferences"
  [ -f "$PREF" ] || continue
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$PREF" <<PY 2>/dev/null || true
import json,sys
p=sys.argv[1]
try:
    d=json.load(open(p))
except Exception:
    sys.exit(0)
d.setdefault("browser",{})["custom_chrome_frame"]=False
json.dump(d,open(p,"w"))
PY
  fi
done
