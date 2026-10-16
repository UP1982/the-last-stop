#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
odin check src
