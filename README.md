# ScreenShotClipboard

A menu bar app that makes `⌘⇧4` put the screenshot on your clipboard **immediately**,
while still leaving the file on your Desktop.

macOS can already do either one of those — `⌘⇧⌃4` copies to the clipboard, and
`⌘⇧5 → Options → Save to` picks a destination — but not both at once. It also
can't do the clipboard part *instantly* while the floating thumbnail is enabled:
the thumbnail is what holds the capture in limbo for ~5 seconds before the file is
written, and nothing can reach a screenshot before it exists on disk.

So this app turns the system thumbnail off and replaces it with its own.

## What happens when you take a screenshot

1. The file lands in your screenshot folder (`~/Desktop` unless you've changed it).
2. It's on the clipboard about 50 ms later — ready to paste before you can switch apps.
3. A small preview appears in the bottom-right corner for 5 seconds:

| What you do | What happens to the Desktop file |
| --- | --- |
| Nothing | Stays on the Desktop |
| Drag the preview into another app | Moved to the Trash — you already put it where you wanted it |
| Click the ✕ | Moved to the Trash |
| Click the preview | Opens it; the file stays |

The clipboard keeps the image in every case, so discarding the file never costs you
the paste.

## Build

```
./build.sh
open ScreenShotClipboard.app
```

Needs the Xcode Command Line Tools — no Xcode project, no dependencies. The binary is
built for Apple Silicon (`arm64`).

It starts watching about 0.7 s after launch. If your Mac is set to ask before letting
apps read the Desktop folder, approve that prompt the first time — the app can't see
your screenshots without it.

Use **Open at Login** in the menu bar item to have it start with your Mac. To move it
somewhere permanent, drag the `.app` to `/Applications` first — the login item points
at wherever the app was when you enabled it.

## Settings it changes

While running, it sets two `com.apple.screencapture` preferences:

- `show-thumbnail` → `false`, because the system thumbnail is the delay.
- `target` → `file`, only if you'd set it to something else; a clipboard-only capture
  would leave no file to save or drag.

**Quit restores both to whatever they were.** If the app is ever force-quit and the
thumbnail doesn't come back, restore it by hand:

```
defaults write com.apple.screencapture show-thumbnail -bool true && killall screencaptureui
```

## When a screenshot doesn't get copied

Run the executable directly with tracing on and take a screenshot:

```
SSC_DEBUG=1 ScreenShotClipboard.app/Contents/MacOS/ScreenShotClipboard
```

Then read `~/Library/Logs/ScreenShotClipboard.log`. It records the folder being
watched, every new file that appears, and whether the file was recognised as a
screenshot. Recognition uses the `kMDItemIsScreenCapture` attribute macOS stamps on
captures, which is what keeps everything else that lands on your Desktop out of your
clipboard.
