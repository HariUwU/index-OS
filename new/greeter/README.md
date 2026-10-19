# INDEX greeter (greetd + Quickshell)

The INDEX lock screen (`../quickshell/lock/lock.qml`) ported to a **greetd login greeter**. It keeps the same black two-column layout, clock, logo, profile frame, intro video with `>_ SKIP _<`, sounds, and the WILL OF THE CITY / FIXER sequence.

- **Media:** the original artwork and sound effects are included. Only intro video and login background music are user-supplied; see [`../assets/README.md`](../assets/README.md). With no intro, login goes straight to the password. The author-modified Universal font remains the default.
- **Entry point:** `greeter.qml`. All assets are under `assets/` and resolved relative to the QML file. Fonts are bundled through `FontLoader`.
- **Install:** `../install-greeter.sh` copies this folder to `/usr/share/index-greeter/`. greetd runs it as the `greeter` user under cage:
  `cage -s -d -- quickshell -p /usr/share/index-greeter/greeter.qml`
- **User:** read from `/usr/share/index-greeter/user` (one line). If the file is missing it falls back to `index`.
- **Session:** on success it calls `Greetd.launch()` with `/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland` and sets `XDG_SESSION_TYPE=wayland` and `XDG_CURRENT_DESKTOP=KDE`.
- **Auth:** each attempt is a single greetd round (`createSession`, `respond`, `readyToLaunch`). After 3 failures the WILL OF THE CITY modal appears. A wrong FIXER password powers the machine off (the original INDEX protocol); a greetd error just returns to the prompt.
- **Intro:** login frequency defaults to **Once per boot** for both supplied assets/intro.mp4 and custom video. After logout, the login screen goes straight to the password. Select **Every login** in INDEX Intro Video settings, or run `python3 tools/index-intro.py --scope login --frequency always` from `new/`, to play whenever the greeter opens. Use `--frequency boot` to restore the default. Changing frequency preserves the selected video and on/off state; changing/resetting video preserves frequency. Lock-screen frequency is independent and unchanged.
- **Override and skipping:** `INDEX_INTRO=0` suppresses playback in either mode; `INDEX_INTRO=1` still respects the configured frequency and enabled state. Press Esc or double-click and use SKIP to skip by hand. It also ends by itself if the video fails or hasn't started within about 2 s.

`run-greeter` atomically claims a directory named after `/proc/sys/kernel/random/boot_id`
under `/var/lib/index-greeter-intro`. The installer provisions this separate
persistent directory with greeter ownership and mode `0700`, after installing
greetd; `/var/lib/index-greeter` backups retain their existing ownership/mode.
Qt's cache remains separate in `/tmp/index-greeter-cache`. Cache age-cleaning and
session runtime cleanup cannot discard the claim. It passes `INDEX_INTRO_BOOT=1` for the first launch
and `0` thereafter. The claim happens before cage starts, even if intro is off,
skipped, fails, or frequency is Every login. Replacing/enabling a video does not
reset the claim: use the settings Preview to watch immediately. Every login
ignores the boot flag. The separate `INDEX_INTRO` suppression still applies.

If kernel identity cannot be read or the claim cannot be stored, boot-only mode
skips playback so login remains available. A direct QML launch without the flag
also skips boot-only playback. The launcher requires the parent to exist and be
writable; it never creates the parent or falls back to cache/runtime storage.
`INDEX_GREETER_INTRO_STATE_DIR` overrides the parent only for isolated tests or
explicit advanced configuration; provision that directory separately with mode
`0700` and greeter ownership. Removing persistent claims or changing that override
can allow another claim. These markers record a launch attempt, not proof that
video was watched. Old boot-ID directories are retained; no cleanup service is added.

For an existing deployment, provision the directory and seed the already-played
current boot before returning to login (no logout or reboot is needed):

```sh
sudo install -d -m 700 -o greeter -g "$(id -gn greeter)" /var/lib/index-greeter-intro
sudo -u greeter sh -c '
  umask 077
  boot_id=$(cat /proc/sys/kernel/random/boot_id) || exit 1
  [ -n "$boot_id" ] || exit 1
  mkdir -p "/var/lib/index-greeter-intro/$boot_id"
'
```

Source-only regression checks (run from `new/`):

```bash
python3 -B tools/test-index-intro.py
python3 -B tools/test-greeter-intro.py
node tools/test-greeter-intro.js
```

The helper tests mock privileged installs and media validation; the shell tests
exercise the real claim block in temporary directories with a fake kernel boot
ID (including concurrent claims, cache/runtime cleanup, absent state, and failed
marker creation); installer provisioning is checked with command stubs. The JS tests evaluate the real startup gate
and focus branch without Qt. They do not validate live cage, Qt playback, PAM,
or KDE layout; those require a separate authorized desktop test. The shell check
requires a local POSIX sh and skips when unavailable; Git for Windows is supported.

**Important:** `Quickshell.Services.Greetd` only works when Quickshell is started *by greetd*, because it needs `$GREETD_SOCK`. If you run `quickshell -p greeter.qml` from a normal desktop session it shows the UI, but every login attempt reports `>_GREETD_OFFLINE._`. Test it for real from a TTY, or with `greetd`'s `fakegreet` tool.

Sound uses `pw-play`/`paplay`/`aplay` and fails silently when the greeter user has no sound server. Power and restart run `systemctl poweroff` / `systemctl reboot`, which needs polkit to allow it for the greeter seat.
