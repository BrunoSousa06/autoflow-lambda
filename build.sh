#!/bin/bash

set -e

rm -rf build
mkdir -p build

pip install \
  -r requirements.txt \
  -t build

cp handler.py build/