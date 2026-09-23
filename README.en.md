<p align="center"><img src="Resources/icona.png" width="160" alt="Tendina icon"></p>

# Tendina

*Versione italiana: [README.md](README.md)*

A tiny menu bar app for macOS that hides the icons you choose and shows them again with one click. Built as a replacement for Hidden Bar (and Ice), which stopped working on macOS 27. "Tendina" is Italian for "roller blind".

## How to use it

* **Choose what to hide**: hold ⌘ and drag the menu bar icons you want to hide **to the left of the │ divider**. Everything to the right of the arrow always stays visible.
* **Show and hide**: click the arrow. `‹` means "some icons are hidden", `›` means "everything is shown".
* **Keyboard**: ⌃⌥⌘B (control, option, command, B).
* **Options**: right-click the arrow.
  * Close again after 10 seconds (on by default). It waits while a menu is open or the pointer is on the menu bar.
  * Open at login.
  * Help, Quit.

The divider is hidden while Tendina is closed: open it first to move more icons.

## Install

You need Xcode or the Command Line Tools.

```sh
git clone https://github.com/massimodascola/tendina.git
cd tendina
sh build.sh --installa
```

This builds `build/Tendina.app`, copies it to `/Applications` and launches it. Without `--installa` it only builds. The app is signed ad hoc for your own Mac: there is no notarized download yet.

## How it works

On macOS 27 Apple rebuilt the menu bar: status items are drawn by a system process (MenuBarAgent) and are no longer separate windows. Hidden Bar used to widen its divider to 10,000 points to push other icons off screen; macOS 27 now discards such an item, so the trick no longer works.

Measured on a 14" MacBook Pro with a notch, macOS 27.0 (26A428), 1800-point wide screen, on 23 September 2026:

* when an item does not fit, macOS moves it to its own overflow menu (the system « button) **together with every item to its left**, leaving no gap;
* an 850-point item is handled that way, a 950-point item is discarded and ignored. The limit is about half the screen width.

So Tendina widens its divider to 44% of the narrowest screen (792 points here): too wide to fit, but below the limit. The divider and everything to its left disappear. To show them, it goes back to 10 points.

Only public Apple APIs are used: no Accessibility, Screen Recording or Input Monitoring permission. The global shortcut uses the old Carbon API, the only one that needs no permission.

## Known limits

* **Full menu bar**: on notched Macs there are about 790 points to the right of the notch. If the visible icons don't all fit when Tendina is open, macOS puts the leftmost ones in its « menu as usual.
* **External displays**: not tested. On a wide screen with lots of free space, hidden icons might reappear.
* **Apple Silicon only** (`arm64`). For Intel, change `-target` in `build.sh`.
* Code, comments and identifiers are in Italian.

## If something breaks

* **The arrow disappeared**: press ⌃⌥⌘B, or open Tendina again from Spotlight (reopening shows everything). Then make sure the divider is to the left of the arrow.
* **Nothing gets hidden**: open Tendina and check that the icons are to the left of the divider. If the divider is to the right of the arrow, Tendina refuses to close and tells you.
* **It stops working after a macOS update**: Apple probably changed the width limit. Try changing `0.44` in `larghezzaChiusa()` in `Sources/Tendina.swift` (lower it if the icons come back), then run `sh build.sh --installa`.
* Don't run Hidden Bar and Tendina at the same time.

## Author and license

Made by **Massimo D'Ascola** ([@massimodascola](https://github.com/massimodascola)). MIT license, see `LICENSE`.

Experimental: tested only on one notched MacBook Pro with macOS 27.0. Issues and pull requests are welcome.
