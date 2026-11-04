<p align="center">
  <img src="ikon.svg" width="128" height="128" alt="Brushtastic icon">
</p>

<h1 align="center">Brushtastic</h1>

<p align="center">
  Draw temporary annotations anywhere on your Mac screen — they fade away on their own.
</p>

---

Brushtastic is a tiny macOS menu bar app for presentations, screen sharing, demos and recordings.
Press a global shortcut, draw on top of everything, and the strokes disappear by themselves a few
seconds later. When drawing mode is off, the overlay is completely click-through, so it never gets
in your way.

## Features

- **Global shortcut ⌃⌥D** (Control + Option + D) toggles drawing mode from any app.
- **Draws over everything** — every display, every Space, and full-screen apps.
- **Click-through when off** — mouse clicks go straight to the apps underneath.
- **Strokes fade out automatically** — after 3 seconds by default, adjustable from 0.5 to 10 seconds.
  Drag the slider all the way to the right and strokes **never** fade.
- **Four tools**, switched with the number keys while drawing:

  | Key | Tool          | With ⇧ Shift held              |
  | --- | ------------- | ------------------------------ |
  | `1` | Freehand      | —                              |
  | `2` | Circle        | Perfect circle                 |
  | `3` | Rectangle     | Perfect square                 |
  | `5` | Straight line | Snaps to 45° angles            |

- **Multiple displays** — a single stroke can cross from one screen to the next.
- **Colors and line widths** — red, yellow, green, blue, pink, white or black; thin, medium or thick.
- **Launch at login** — one click in the menu.
- **No Dock icon** — lives only in the menu bar.
- **Norwegian and English** — shown in Norwegian when macOS's preferred language is Norwegian
  (Bokmål, Nynorsk or "Norsk"), otherwise English.
- **No special permissions** — the shortcut does not require Accessibility access.

## Usage

| Action                         | How                                         |
| ------------------------------ | ------------------------------------------- |
| Start / stop drawing           | ⌃⌥D, or **Start Drawing** in the menu bar   |
| Choose a tool                  | `1`, `2`, `3` or `5` while drawing          |
| Constrain shape / line angle   | Hold ⇧ Shift while dragging                 |
| Clear everything               | Right-click while drawing, or **Clear All** |
| Exit drawing mode              | `Esc` or ⌃⌥D                                |
| Change fade-out delay          | Slider in the menu bar menu                 |

While drawing mode is on, the screen gets a faint tint and an accent-colored border, and a toolbar
at the top of the screen shows which tool is selected.

## Installation

### Homebrew (recommended)

```sh
brew install gauteweb/tap/brushtastic
```

Homebrew builds the app from source on your Mac, so it works on both Apple silicon and Intel and
opens without any Gatekeeper warning. Start it with:

```sh
open "$(brew --prefix brushtastic)/Brushtastic.app"
```

To have it in Launchpad and Spotlight as well, link it into `~/Applications`:

```sh
ln -sf "$(brew --prefix brushtastic)/Brushtastic.app" ~/Applications/Brushtastic.app
```

Update or remove it with:

```sh
brew upgrade brushtastic
brew uninstall brushtastic
```

> After `brew upgrade`, quit Brushtastic and open it again. If you use **Launch at Login**, turn
> it off and on again in the menu so it points to the new version.

### Download

1. Download `Brushtastic.zip` from the [latest release](../../releases/latest).
2. Unzip it and move **Brushtastic.app** to `/Applications`.
3. The app is not notarized by Apple, so the first time you open it macOS will block it.
   Go to **System Settings → Privacy & Security** and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Brushtastic.app
   ```

### Build from source

Requires macOS 13 or later and the Xcode Command Line Tools (full Xcode is not needed).

```sh
git clone https://github.com/Gauteweb/Brushtastic.git
cd Brushtastic
./build.sh
open build/Brushtastic.app
```

`build.sh` compiles the app with `swiftc`, builds the app icon from `AppIcon.png`, assembles
`build/Brushtastic.app` and signs it ad hoc. The version number is set at the top of `build.sh`.

After changing `ikon.svg`, run `./make-icon.sh` to regenerate `AppIcon.png` and commit both.
`Package.swift` is included so the project can be opened in Xcode or built with `swift build`
during development.

> If you enable **Launch at Login**, run the app from `/Applications` — the login item points to
> the app's location, and `build/` is recreated on every build.

## Project structure

| File                                    | Purpose                                                  |
| --------------------------------------- | -------------------------------------------------------- |
| `Sources/Brushtastic/AppDelegate.swift` | Menu bar item, menu, drawing mode, display/Space changes |
| `Sources/Brushtastic/Overlay.swift`     | Transparent per-screen overlay, input, rendering         |
| `Sources/Brushtastic/StrokeStore.swift` | Strokes and shapes, fade-out animation                   |
| `Sources/Brushtastic/Tool.swift`        | Drawing tools                                            |
| `Sources/Brushtastic/HotKey.swift`      | Global shortcut (Carbon `RegisterEventHotKey`)           |
| `Sources/Brushtastic/Settings.swift`    | User preferences (`UserDefaults`)                        |
| `Sources/Brushtastic/Localization.swift`| Norwegian and English strings                            |
| `build.sh`                              | Builds and packages the `.app` (also used by Homebrew)   |
| `make-icon.sh`                          | Renders `AppIcon.png` from `ikon.svg`                    |
| `ikon.svg`                              | App icon source                                          |
| `AppIcon.png`                           | Rendered app icon used by `build.sh`                     |

## Known limitations

- The ⌃⌥D shortcut cannot be changed. If another app already uses it, start drawing from the menu.
- The downloadable app is signed ad hoc and not notarized, so Gatekeeper asks for confirmation on
  first launch. Installing with Homebrew avoids this.
- The downloadable app is for Apple silicon only. On an Intel Mac, install with Homebrew or build
  from source.

## License

Brushtastic is released under the [MIT License](LICENSE).
