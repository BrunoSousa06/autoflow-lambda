#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

rm -rf build
mkdir -p build

pip install -r requirements.txt -t build

cp handler.py build/