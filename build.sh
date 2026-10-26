#!/bin/zsh
# Builds ScrollFlip.app and installs it to /Applications.
# Note: each rebuild changes the ad-hoc signature, so macOS will ask for
# Accessibility again — remove the old ScrollFlip entry and re-allow.
set -e
cd "$(dirname "$0")"
APP=build/ScrollFlip.app
rm -rf build && mkdir -p $APP/Contents/MacOS
swiftc -O main.swift -o $APP/Contents/MacOS/ScrollFlip
cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.josh.scrollflip</string>
  <key>CFBundleName</key><string>ScrollFlip</string>
  <key>CFBundleExecutable</key><string>ScrollFlip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
EOF
codesign --force --sign - $APP
rm -rf /Applications/ScrollFlip.app
cp -R $APP /Applications/
echo "Installed /Applications/ScrollFlip.app"
