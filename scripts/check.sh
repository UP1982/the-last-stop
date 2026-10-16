#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
odin check src
odin check shared/content
mkdir -p build
odin build tools/content -out:build/tls-content
odin run tests/editor -out:build/e0-allocation -- .
python3 -B tests/editor/run.py
