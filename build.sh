#!/bin/bash
set -e

echo "=== Installing Flutter SDK on Vercel ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

echo "=== Flutter Doctor ==="
flutter doctor -v

echo "=== Enabling Web ==="
flutter config --enable-web

echo "=== Getting Packages ==="
flutter pub get

echo "=== Building Flutter Web for Release ==="
flutter build web --release --no-wasm-dry-run --no-tree-shake-icons

echo "=== Flutter Web Build Complete in build/web ==="
