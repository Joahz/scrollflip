# ScrollFlip

A tiny macOS menu-bar app that reverses **mouse-wheel** scrolling only. Your trackpad (and Magic Mouse) keep natural scrolling, and a regular notched mouse wheel scrolls the Windows way.

## How it works

macOS has one "natural scrolling" switch for both mouse and trackpad. ScrollFlip watches the stream of scroll events. Trackpad events are marked as *continuous* and have gesture phases; notched wheel events don't. ScrollFlip flips the direction of the wheel events only.

## Install (prebuilt)

1. Download `ScrollFlip.zip` from [Releases](../../releases), unzip it, and move `ScrollFlip.app` to `/Applications`.
2. The app isn't notarized, so macOS will block it the first time. Either right-click → **Open**, or use System Settings → Privacy & Security → **Open Anyway**. You can also run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ScrollFlip.app
   ```
3. Launch it and grant **Accessibility** permission when asked (System Settings → Privacy & Security → Accessibility). The menu-bar icon shows a ⚠️ until you do.

## Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`). Requires macOS 13 or later.

```bash
./build.sh
```

This compiles `main.swift`, ad-hoc signs the app, and installs it to `/Applications`. Each rebuild changes the signature, so remove the old ScrollFlip entry under Accessibility and allow it again.

## Menu

- **Reverse Mouse Wheel** turns the flip on or off.
- **Launch at Login** adds or removes `~/Library/LaunchAgents/com.josh.scrollflip.plist`.
- **Quit ScrollFlip**

## Support

ScrollFlip is free. If it saves you some annoyance, you can [buy me a coffee](https://buymeacoffee.com/slokey) ☕
