# ScreenShotClipboard

![ScreenShotClipboard demo](docs/demo.gif)

Press ⌘⇧4. The screenshot is on your clipboard right away, and the file still saves to your Desktop.

macOS gives you one or the other. ⌘⇧⌃4 copies without saving a file, and the "Save to" setting in ⌘⇧5 swaps the destination. Neither is instant while the floating thumbnail is switched on, because that thumbnail holds the capture for about 5 seconds before the file gets written. This app switches it off and shows its own preview instead.

## Install

1. Download `ScreenShotClipboard.zip` from the [latest release](https://github.com/spozar/ScreenShotClipboard/releases/latest).
2. Unzip it and move `ScreenShotClipboard.app` into your Applications folder.
3. Open it. The app is signed and notarized, so it opens like any other. Allow Desktop access when macOS asks: that is where the screenshots land.
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

The clipboard keeps the image in all four cases. Dragging hands the other app its own copy, so chat apps and browsers get the real image even though the Desktop file is gone.

The menu bar icon has the settings:

* **Show Preview** switches the preview off entirely. Screenshots still copy and save.
* **Preview Position** puts it in any corner of the screen.
* **Preview Duration** keeps it up for 3, 5, 10 or 30 seconds. Hovering over it holds it there.
* **Trash File After Drag or Close** off keeps every file on the Desktop.

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

## Releasing

```
./release.sh
```

It builds, signs with your Developer ID certificate, sends the app to Apple for notarization, staples the ticket and leaves `ScreenShotClipboard.zip` ready to upload. People who download that zip open the app with a plain double click.

It needs two things set up once:

1. A "Developer ID Application" certificate in your keychain. Xcode > Settings > Accounts > Manage Certificates creates one.
2. Notarization credentials saved under the name `notary`. Make an app-specific password at [appleid.apple.com](https://appleid.apple.com), then:

   ```
   xcrun notarytool store-credentials notary --apple-id you@example.com --team-id 99476Z45K6
   ```

The script checks both before it builds anything and tells you which one is missing.

## If a screenshot does not get copied

Run it with tracing on, then take a screenshot:

```
SSC_DEBUG=1 ScreenShotClipboard.app/Contents/MacOS/ScreenShotClipboard
```

Read `~/Library/Logs/ScreenShotClipboard.log`. It records the folder being watched and every file that shows up in it. Screenshots are picked out by the `kMDItemIsScreenCapture` attribute macOS stamps on them, which is how the rest of your Desktop stays out of your clipboard.
