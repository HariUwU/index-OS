# INDEX native screen locker

`LockScreen.qml` is the native Plasma 6.6 entry point. It preserves the original
black two-column terminal, logo, framed profile, pixel typeface, scramble/status
animation, intro, sounds, and third-failure "WILL OF THE CITY" sequence.

It must be installed as `contents/lockscreen/LockScreen.qml` in a `Plasma/Shell`
package with `X-Plasma-APIVersion: 2`, and a fallback to
`org.kde.plasma.desktop`. Merely placing it inside a global theme does not select
it on Plasma 6.6. The installer can copy this directory into the INDEX shell
package as well as retaining it in the global theme.

The assets installer must copy `quickshell/lock/assets` into `assets/` here.
Required: `PerfectDOSVGA437-Universal.ttf`, `Logo.png`, `DefaultProfile.jpg`,
`sounds/bg.mp3`, `sounds/click.wav`, `sounds/check.wav`, `sounds/fail.wav`, and
`sounds/success.wav`. `intro.mp4` is optional: missing/unplayable media skips
immediately. Existing assets are reused without alteration.

## Verified Plasma 6.6 contracts

The guest's native source files live under
`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/`.
The current guest is Plasma 6.6.6; the 6.6 source contracts below were checked
against its installed native locker QML and executable options.

- [`greeterapp.cpp`](https://invent.kde.org/plasma/kscreenlocker/-/blob/Plasma/6.6/greeter/greeterapp.cpp)
  sets `authenticator` to `PamAuthenticators`, supplies `kscreenlocker_userName`
  and `kscreenlocker_userImage`, writes root properties `locked`, `viewVisible`,
  `suspendToRamSupported` and `suspendToDiskSupported`, and guards `Qt.quit()`
  with `m_authenticators->isUnlocked()`.
- [`pamauthenticators.h`](https://invent.kde.org/plasma/kscreenlocker/-/blob/Plasma/6.6/greeter/pamauthenticators.h)
  exposes `startAuthenticating()`, `respond(QByteArray)`, `busy`, `unlocked`,
  prompt/message properties, `failed(kind, authenticator)`,
  `loginFailedDelayStarted(kind, authenticator, microseconds)` and `succeeded()`.
  Only interactive failures (`Authenticator.None`) count toward the sequence.
- [`shell_integration.cpp`](https://invent.kde.org/plasma/kscreenlocker/-/blob/Plasma/6.6/settings/shell_integration.cpp)
  reads `plasmashellrc`, `[Shell]`, `ShellPackage` to choose the shell. `Greeter`
  `Theme` in `kscreenlockerrc` does not select a custom locker on this version.
- [`main.cpp`](https://invent.kde.org/plasma/kscreenlocker/-/blob/Plasma/6.6/greeter/main.cpp)
  accepts `--testing --shell org.index.desktop`. The shell override is only
  honored in testing mode. A real lock uses the selected shell package.
- [`libplasma shellpackage.cpp`](https://invent.kde.org/plasma/libplasma/-/blob/Plasma/6.6/src/plasma/packagestructure/shell/shellpackage.cpp)
  loads `X-Plasma-FallbackPackage` for a custom shell (defaulting to
  `org.kde.plasma.desktop`). Desktop views and panel furniture can therefore
  continue to use the installed, matching native Plasma shell.

Settings are read from `kscreenlockerrc [Greeter][LnF][General]` using `config.xml`:
`indexIntro=true`, `indexVolume=0.3` (range 0–1). Audio is emitted by the focused
screen only. All screens share the native authenticator; the in-memory edit
buffer follows KDE's `PasswordSync` approach and clears on submit/failure/success.
Extra native PAM prompts are displayed and accept another response. No failure
path runs commands, shuts down the machine, or changes authentication policy.
The intro plays on each lock when enabled; set `indexIntro=false` to show the
terminal immediately. It is always skippable.
The matching `config.qml` presents these settings in KDE's native screen-lock
settings page, using its `cfg_` property bridge instead of stock clock controls.

The target is Plasma 6.6 with Qt 6. Its runtime modules are `QtQuick`,
`QtQuick.Window`, `QtQuick.Controls`, `QtMultimedia`, the Plasma workspace
components and keyboard indicator modules, and the native greeter's registered
`org.kde.kscreenlocker` module. The Ubuntu VM preparation includes
`qml6-module-qtmultimedia` in addition to the regular Plasma desktop packages.

## Preview without locking

Use `tools/kde-lock-preview.sh` after installation. It invokes the real greeter
with `--testing --shell org.index.desktop` through XWayland to keep the preview
in a regular closable window. It does not invoke the screen-lock service.
Stop the preview with Ctrl+C in its terminal; the native greeter can remain
running after its testing window is closed.
For noninteractive load validation use `QT_QPA_PLATFORM=offscreen timeout 8s
/usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet --testing --shell
org.index.desktop`; a timeout exit code is expected if the QML loaded.
