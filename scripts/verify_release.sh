#!/usr/bin/env bash
set -euo pipefail
make tools
make matrix
make codegen
make verify
swift test --package-path swift/Midi2Swift
