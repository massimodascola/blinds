<p align="center"><img src="Resources/icon.png" width="160" alt="Blinds icon"></p>

# Blinds

*Leggi in italiano: [README.it.md](README.it.md)*

A tiny menu bar app for macOS that hides the icons you choose and shows them again with one click. Built as a replacement for Hidden Bar (and Ice), which stopped working on macOS 27.

Blinds was called Tendina in its first two releases. Installing Blinds replaces Tendina and keeps its settings.

## Install

Three ways, pick one. All of them build the app on your own Mac, so no Apple signature is needed and no security warning shows up.

You need an Apple Silicon Mac and Apple's developer tools. If you don't have them, install them for free with `xcode-select --install`.

### 1. One command

```sh
curl -fsSL https://raw.githubusercontent.com/massimodascola/blinds/master/install.sh | sh
```

Downloads the source, builds it, copies Blinds to Applications and launches it. Run the same command again to update. The script is [install.sh](install.sh): read it first if you want to know what it does.

### 2. Homebrew

```sh
brew install massimodascola/tap/blinds
blinds-install
```

Homebrew builds Blinds but cannot copy apps into Applications on its own: the `blinds-install` command does that. To update:

```sh
brew upgrade blinds && blinds-install
```

### 3. From source

```sh
git clone https://github.com/massimodascola/blinds.git
cd blinds
sh build.sh --install
```

To update, from the `blinds` folder: `git pull && sh build.sh --install`. Without `--install`, `build.sh` only builds `build/Blinds.app`.

### Uninstall

In Blinds' menu untick "Open at Login", then choose "Quit Blinds", then move `/Applications/Blinds.app` to the Trash. If you used Homebrew, also run `brew uninstall blinds`.

## How to use it

* **Choose what to hide**: hold ⌘ and drag the menu bar icons you want to hide **to the left of the │ divider**. Everything to the right of the arrow always stays visible.
* **Show and hide**: click the arrow. `‹` means "some icons are hidden", `›` means "everything is shown".
* **Keyboard**: ⌃⌥⌘B (control, option, command, B).
* **Options**: right-click the arrow.
  * Hide Again After 10 Seconds (on by default). It waits while a menu is open or the pointer is on the menu bar.
  * Open at Login.
  * How to Use, Quit Blinds.

The divider is hidden while Blinds is collapsed: expand it first to move more icons.

The app is in English, with an Italian translation that macOS picks automatically when your Mac is set to Italian.

## How it works

On macOS 27 Apple rebuilt the menu bar: status items are drawn by a system process (MenuBarAgent) and are no longer separate windows. Hidden Bar used to widen its divider to 10,000 points to push other icons off screen; macOS 27 now discards such an item, so the trick no longer works.

Measured on a 14" MacBook Pro with a notch, macOS 27.0 (26A428), 1800-point wide screen, on 23 September 2026:

* when an item does not fit, macOS moves it to its own overflow menu (the system « button) **together with every item to its left**, leaving no gap;
* an 850-point item is handled that way, a 950-point item is discarded and ignored. The limit is about half the screen width.

So Blinds widens its divider to 44% of the narrowest screen (792 points here): too wide to fit, but below the limit. The divider and everything to its left disappear. To show them, it goes back to 10 points.

On macOS 26 and earlier, status items are still separate windows. There Blinds uses the classic Hidden Bar and Ice method: a 10,000-point divider that pushes everything to its left off screen.

Only public Apple APIs are used: no Accessibility, Screen Recording or Input Monitoring permission. The global shortcut uses the old Carbon API, the only one that needs no permission.

## Compatibility

* **macOS 27**: tested (notched MacBook Pro, macOS 27.0).
* **macOS 13 to 26**: should work with the classic method, but it is **not tested**. If you run it on one of these versions, please open an issue, even just to say it works.

## Known limits

* **Full menu bar**: on notched Macs there are about 790 points to the right of the notch. If the visible icons don't all fit when Blinds is expanded, macOS puts the leftmost ones in its « menu as usual.
* **External displays**: not tested. On a wide screen with lots of free space, hidden icons might reappear.
* **Apple Silicon only** (`arm64`). For Intel, change `-target` in `build.sh`.
* The app is signed ad hoc by the Mac that builds it. There is no prebuilt download.

## If something breaks

* **The arrow disappeared**: press ⌃⌥⌘B, or open Blinds again from Spotlight (reopening shows everything). Then make sure the divider is to the left of the arrow.
* **Nothing gets hidden**: expand Blinds and check that the icons are to the left of the divider. If the divider is to the right of the arrow, Blinds refuses to collapse and tells you.
* **It stops working after a macOS update**: Apple probably changed the width limit (macOS 27 and later). Try changing `0.44` in `collapsedDividerWidth()` in `Sources/Blinds.swift` (lower it if the icons come back), then run `sh build.sh --install`.
* Don't run Hidden Bar and Blinds at the same time.

## Files

* `Sources/Blinds.swift`: the whole app (a single, commented file).
* `Resources/Info.plist`: name, identifier and no Dock icon. The identifier is still `com.massimodascola.tendina`, from the first release, so macOS keeps icon positions and settings.
* `Resources/en.lproj`, `Resources/it.lproj`: the app's texts in English (default) and Italian.
* `Resources/Blinds.icns`, `Resources/icon.png`: the icon, a window with a half-lowered shade on the macOS 27 system blue (`#0088FF`).
* `tools/draw-icon.swift`, `tools/make-icon.sh`: draw the icon and convert it. Only needed when the drawing changes.
* `Resources/logo/`: the logo kit (mark, black and white symbol, logo for light and dark backgrounds), as SVG and PNG. Generated by `tools/make-logo-kit.swift`; the name is set in [Inter](https://github.com/rsms/inter) (SIL Open Font License 1.1).
* `build.sh`: builds, signs and installs.
* `install.sh`: one-command install (downloads the source and runs `build.sh`).
* The Homebrew formula lives in a separate repo: [massimodascola/homebrew-tap](https://github.com/massimodascola/homebrew-tap).

## Author and license

Made by **Massimo D'Ascola** ([@massimodascola](https://github.com/massimodascola)). MIT license, see `LICENSE`.

Experimental: tested only on one notched MacBook Pro with macOS 27.0. Issues and pull requests are welcome.
