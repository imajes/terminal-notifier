#!/usr/bin/env bash
set -euo pipefail

# Redirect caches to workspace to avoid sandboxed locations.
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT_DIR/.home/.cache/clang/ModuleCache"
mkdir -p "$ROOT_DIR/.build/clang-module-cache"
mkdir -p "$ROOT_DIR/.build/swift-module-cache"

export HOME="$ROOT_DIR/.home"
export MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$ROOT_DIR/.build/swift-module-cache"

CMD=${1:-build}
shift || true

if [[ "$CMD" == "build" ]]; then
  swift build \
    -Xcc -fmodules-cache-path=$MODULE_CACHE_DIR \
    -Xswiftc -module-cache-path -Xswiftc $SWIFT_MODULECACHE_PATH "$@"
elif [[ "$CMD" == "test" ]]; then
  swift test \
    -Xcc -fmodules-cache-path=$MODULE_CACHE_DIR \
    -Xswiftc -module-cache-path -Xswiftc $SWIFT_MODULECACHE_PATH "$@"
else
  echo "Usage: bin/build-local.sh [build|test] [swift-args...]" >&2
  exit 2
fi
