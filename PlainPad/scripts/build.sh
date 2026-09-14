#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/PlainPad.app/Contents/MacOS build/PlainPad.app/Contents/Resources build/module-cache
swiftc -swift-version 5 -O -target "$(uname -m)-apple-macos13.0" -module-cache-path build/module-cache -module-name PlainPad Sources/*.swift -o build/PlainPad-new -framework AppKit
mv build/PlainPad-new build/PlainPad.app/Contents/MacOS/PlainPad
sed 's/$(PRODUCT_MODULE_NAME)/PlainPad/g' Resources/Info.plist > build/PlainPad.app/Contents/Info.plist
cp Resources/AppIcon.icns build/PlainPad.app/Contents/Resources/
codesign --force --sign - build/PlainPad.app
printf 'Built: %s/build/PlainPad.app\n' "$PWD"
