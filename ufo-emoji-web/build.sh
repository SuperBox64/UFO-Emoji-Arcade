#!/usr/bin/env bash
# UFO Emoji, SpriteKit edition, build helper. Wraps `swift build` with the
# swift.org toolchain + wasm SDK so wasm32-wasip1 finds the KitABI C shim
# (Xcode's bundled clang has no wasm backend, so we go through xcrun
# --toolchain swift to pick the swift.org clang the wasm SDK was built against).
#
# Usage:
#   ./build.sh            # debug
#   ./build.sh release    # release (-Osize, stripped, wasm-opt -Oz)
#
# WasmKit (the JS runtime) is expected as a sibling checkout, ../../WasmKit,
# resolved from this script's location so it never depends on the caller's cwd.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WASMKIT="$SCRIPT_DIR/../../WasmKit"
if [ ! -d "$WASMKIT" ]; then
  echo "→ Cloning WasmKit..."
  git clone https://github.com/SuperBox64/WasmKit "$WASMKIT"
fi

SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-org.swift.6.3.2-release}"
WASM_SDK="${WASM_SDK:-swift-6.3.2-RELEASE_wasm}"

CONFIG_ARGS=()
PASSTHROUGH=()
IS_RELEASE=0
for arg in "$@"; do
  case "$arg" in
    release) CONFIG_ARGS=(-c release -Xswiftc -Osize -Xlinker -s -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata); IS_RELEASE=1 ;;
    debug)   CONFIG_ARGS=(-c debug) ;;
    *)       PASSTHROUGH+=("$arg") ;;
  esac
done

echo "→ swift build  (toolchain=$SWIFT_TOOLCHAIN  sdk=$WASM_SDK)"
TOOLCHAINS="$SWIFT_TOOLCHAIN" \
  xcrun --toolchain swift swift build \
  --swift-sdk "$WASM_SDK" \
  "${CONFIG_ARGS[@]}" \
  "${PASSTHROUGH[@]}"

if [ "$IS_RELEASE" = "1" ]; then
  REL=.build/wasm32-unknown-wasip1/release/UFOEmoji.wasm
  if command -v wasm-opt >/dev/null 2>&1; then
    wasm-opt -Oz \
      --enable-bulk-memory --enable-nontrapping-float-to-int \
      --enable-sign-ext --enable-mutable-globals --enable-multivalue \
      "$REL" -o web/ufoemoji.wasm
    echo
    echo "✓ Release artifact published (wasm-opt -Oz): web/ufoemoji.wasm"
  else
    cp "$REL" web/ufoemoji.wasm
    echo
    echo "✓ Release artifact published (install binaryen for a smaller wasm): web/ufoemoji.wasm"
  fi
else
  cp .build/wasm32-unknown-wasip1/debug/UFOEmoji.wasm web/ufoemoji.wasm
  echo
  echo "✓ Debug artifact published: web/ufoemoji.wasm"
fi

# Generate the asset manifest the runtime preloads from, and ship the runtime.
source "$WASMKIT/build.sh"
wasmweb_manifest web/assets web/manifest.json
rm -f web/runtime.js
cp "$WASMKIT/runtime.js" web/runtime.js
echo "✓ runtime.js + manifest.json published"
