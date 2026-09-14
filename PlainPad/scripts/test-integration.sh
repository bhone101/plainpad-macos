#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -swift-version 5 -O -module-cache-path build/module-cache Sources/TextModel.swift Sources/Preferences.swift Sources/Document.swift Sources/Editor.swift Sources/FindController.swift Tests/TestCases.swift Tests/IntegrationRunner.swift -o build/PlainPadIntegrationTests -framework AppKit
build/PlainPadIntegrationTests
