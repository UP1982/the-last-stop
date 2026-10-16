#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
odin check src
odin check shared/content
mkdir -p build
odin build tools/content -out:build/tls-content
odin run tests/editor -out:build/e0-allocation -- .
python3 -B tests/editor/run.py
odin run src -define:M0_SELF_TEST=true -out:build/m0-selftest
odin run src -define:M1_SELF_TEST=true -out:build/m1-selftest
python3 -B tests/runtime/run.py
python3 -B tests/runtime/m2.py
python3 -B tests/runtime/m2_fix.py
python3 -B -m unittest discover -s tests/editor_ui -v
python3 -B -m unittest discover -s tests/editor_workspace -v
python3 -B -m unittest discover -s tests/editor_reliability -v
python3 -B tests/story/run.py
python3 -B tests/story/runtime.py
python3 -B tests/assets/test_manifest.py
python3 -B tests/assets/runtime.py

python3 -B tests/resilience/run.py --quick

python3 -B tests/dev_editor/run.py
