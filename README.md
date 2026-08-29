# ScreenShotClipboard

Press ⌘⇧4. The screenshot is on your clipboard right away, and the file still saves to your Desktop.

macOS gives you one or the other. ⌘⇧⌃4 copies without saving a file, and the "Save to" setting in ⌘⇧5 swaps the destination. Neither is instant while the floating thumbnail is switched on, because that thumbnail holds the capture for about 5 seconds before the file gets written. This app switches it off and shows its own preview instead.

## Install

1. Download `ScreenShotClipboard.zip` from the [latest release](https://github.com/spozar/ScreenShotClipboard/releases/latest).
2. Unzip it and move `ScreenShotClipboard.app` into your Applications folder.
3. Open it. macOS refuses the first time, because the app is not signed with a paid developer certificate. Go to System Settings > Privacy & Security, scroll to the bottom, and click "Open Anyway". Or do it in Terminal:

   ```
   xattr -dr com.apple.quarantine /Applications/ScreenShotClipboard.app
   ```

4. Click the camera icon in the menu bar and switch on "Open at Login".

Requires macOS 13 or later. Runs on Apple Silicon and Intel.

## How it behaves

Take a screenshot the way you always have. A preview shows up in the bottom right corner for 5 seconds.

| What you do | What happens to the file |
| --- | --- |
| Nothing | Stays on the Desktop |
| Drag the preview into another app | Goes to the Trash |
| Click the x | Goes to the Trash |
| Click the preview | Opens it, file stays |

The clipboard keeps the image in all four cases.

## Settings it changes

While running, it sets two `com.apple.screencapture` preferences:

* `show-thumbnail` to false, since the thumbnail is what causes the delay.
* `target` to `file`, but only if you had changed it. A clipboard-only capture leaves no file to save or drag.

Quitting puts both back the way they were. If it ever gets force quit and the thumbnail does not come back:

```
defaults write com.apple.screencapture show-thumbnail -bool true && killall screencaptureui
```

## Build from source

```
./build.sh
open ScreenShotClipboard.app
```

Needs the Xcode Command Line Tools. No Xcode project, no dependencies.

## If a screenshot does not get copied

Run it with tracing on, then take a screenshot:

```
SSC_DEBUG=1 ScreenShotClipboard.app/Contents/MacOS/ScreenShotClipboard
```

Read `~/Library/Logs/ScreenShotClipboard.log`. It records the folder being watched and every file that shows up in it. Screenshots are picked out by the `kMDItemIsScreenCapture` attribute macOS stamps on them, which is how the rest of your Desktop stays out of your clipboard.
