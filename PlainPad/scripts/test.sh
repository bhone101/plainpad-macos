#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -swift-version 5 -O -module-cache-path build/module-cache Sources/TextModel.swift Tests/TestCases.swift Tests/TestRunner.swift -o build/PlainPadCoreTests
build/PlainPadCoreTests
