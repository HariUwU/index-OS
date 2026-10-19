# Optional personal files

The original INDEX logo, wallpaper, profile image, Power/Restart icons and
sound effects are included. Only the intro video and login background music
are omitted. With no intro, the password screen opens immediately; with no
background music, login stays quiet apart from the included sound effects.

The bundled `PerfectDOSVGA437-Universal.ttf` is the INDEX author's modified
multilingual font. It is used for KDE and INDEX. Do not replace it with another
font in a media folder.

## Source installation

For an intro or login background music, put your own files in this `assets/` folder **before** running
the source installer's `bash install.sh` (at the repository root). Use the exact
filenames `intro.mp4` and `sounds/bg.mp3`. Both are optional. The included
artwork and effects can also be overridden using the names below.

## Pacman installation

Install the package normally. Before running `index-setup`, put your optional
files in `~/.local/share/index/assets/`, using the same filenames. If you set
`XDG_DATA_HOME`, use `$XDG_DATA_HOME/index/assets/` instead. Then run `index-setup`
and select the screens/components to update. No editing `/usr/share` is needed.

To change just the intro after setup, use **Win+A → Settings → Intro Video →
Choose Video → Use Video**. This validates and copies the chosen file. Login
changes request your Linux password; lock and login video choices are separate.

## Filenames

| File relative to the assets folder | Used for |
|---|---|
| `wall.png` | Desktop wallpaper |
| `Logo.png` | Optional desktop/login/lock/splash emblem |
| `Power.png`, `Restart.png` | Optional power controls |
| `intro.mp4` | Optional initial intro, selected through setup |
| `sounds/bg.mp3` | Lock/login background music |
| `sounds/click.wav` | Lock/login click sound |
| `sounds/check.wav` | Authentication checking sound |
| `sounds/success.wav`, `sounds/fail.wav` | Authentication result sounds |
| `sounds/ui/notify.wav`, `sounds/ui/tick.wav` | Desktop notification/tick |
| `sounds/ui/connect.wav`, `sounds/ui/disconnect.wav` | Device connection sounds |
| `sounds/ui/menu.wav`, `sounds/ui/error.wav` | Desktop menu/error sounds |
| `sounds/ui/scramble.mp3` | Prescript scramble sound |

Example optional personal layout:

```text
~/.local/share/index/assets/
├── wall.png
├── intro.mp4
└── sounds/
    └── bg.mp3
```

Your account photo is managed in KDE's Users settings; an account without a
photo uses the standard KDE user icon. `DefaultProfile.jpg` is not required.

The personal folder takes priority over files in a source checkout. Saved
custom intro choices take priority over `intro.mp4`; choose **Use your
assets/intro.mp4** in Intro Video settings to switch back. With no such file,
that action skips the intro. Once-per-boot login playback remains the default.

Personal intro videos and `sounds/bg.mp3` are ignored by Git and excluded from
source archives and pacman builds, even when present locally. The original
images, wallpaper and sound effects remain bundled.
