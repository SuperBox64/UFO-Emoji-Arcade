#!/usr/bin/env bash
# Build the FULL UFO Emoji game as an Embedded-Swift wasm and publish it next to
# the normal web payload. Mirrors BossMan/docs/embedded/build-embedded-game.sh,
# adapted for UFO Emoji: the kit framework modules UFO imports (SpriteKit, AppKit,
# UIKit, AVFoundation) + the game compile under -enable-experimental-feature
# Embedded, link with Box2D v3 (pure C) + the embedded stdlib + WASI libc, and
# boot in the stock runtime.js. No C++ in the link.
#
# Prereqs: swift 6.3.2 toolchain, the swift-6.3.2-RELEASE_wasm SDK, wasm-opt.
# Run a normal `./build.sh release` in ufo-emoji-web first so (a) KitABI's
# shim.c.o is already compiled for wasm and (b) Sources/UFOEmoji is populated
# with the build-time-transformed game sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Framework: local sibling checkout (dev) or the SwiftPM checkout (CI).
FW="$(cd "$ROOT/../SuperBox64Kit" 2>/dev/null && pwd || true)"
[ -d "$FW/Sources/SpriteKit" ] || FW="$(find "$ROOT/ufo-emoji-web/.build" -maxdepth 3 -type d -name SuperBox64Kit 2>/dev/null | head -1)"
GAMESRC="$ROOT/ufo-emoji-web/Sources/UFOEmoji"
# Derive the toolchain + wasm SDK locations (portable: works locally and in CI).
# Pin a stable RELEASE toolchain (this build is validated on swift-6.3.2-RELEASE,
# whose embedded stdlib matches the swift-6.3.2-RELEASE_wasm SDK). EMB_TOOLCHAIN
# overrides. Don't use `xcrun --toolchain swift`: a `swiftly`-installed dev
# snapshot repoints swift-latest and would silently be picked instead.
TC="${EMB_TOOLCHAIN:-}"
if [ -z "$TC" ]; then
  TC="$(ls -d "$HOME"/Library/Developer/Toolchains/swift-*-RELEASE.xctoolchain /Library/Developer/Toolchains/swift-*-RELEASE.xctoolchain 2>/dev/null | sort | tail -1 || true)"
  [ -n "$TC" ] || { TC="$(dirname "$(dirname "$(xcrun --toolchain swift -f swiftc)")")"; TC="${TC%/usr}"; }
fi
SWIFTC="$TC/usr/bin/swiftc"
[ -x "$SWIFTC" ] || { echo "ERROR: no swiftc at $SWIFTC (set EMB_TOOLCHAIN to a toolchain dir)"; exit 1; }
SDK="$(dirname "$(find "$HOME/Library/org.swift.swiftpm/swift-sdks" -type d -name "wasm32-unknown-wasip1" 2>/dev/null | head -1)")/wasm32-unknown-wasip1"
SYSLIB="$SDK/WASI.sdk/lib/wasm32-wasip1"
UNI="$(find "$TC/usr/lib/swift/embedded/wasm32-unknown-none-wasm" -name libswiftUnicodeDataTables.a | head -1)"
WASMLD="$TC/usr/bin/wasm-ld"
CLANG="$(find "$TC" -name clang | head -1)"
B="${EMB_BUILD_DIR:-$(mktemp -d)}"; mkdir -p "$B/src" "$B/mod"

# @MainActor isn't vended by the Embedded stdlib (single-threaded wasm). Strip it
# (and the `{ @MainActor in` closure form) at preprocess time; drop the per-target
# .defaultIsolation(MainActor.self) by building with raw swiftc (no SwiftPM).
strip() { sed -e 's/{ @MainActor in/{/g' -e 's/@MainActor //g' -e 's/@MainActor//g' "$1"; }

# CBox2D's public headers pull libc headers (math.h/stdint.h); the bare-metal
# Embedded target has no sysroot, so point the ClangImporter at wasi-libc's.
SYSINC="$SDK/WASI.sdk/include/wasm32-wasip1"
EMB=(-enable-experimental-feature Embedded -wmo -Osize -parse-as-library
     -target wasm32-unknown-none-wasm
     -Xcc -fmodule-map-file="$FW/Sources/KitABI/include/module.modulemap"
     -Xcc -fmodule-map-file="$FW/Sources/CBox2D/include/module.modulemap"
     -Xcc -isystem -Xcc "$SYSINC"
     -I "$FW/Sources/KitABI/include" -I "$FW/Sources/CBox2D/include" -I "$B/mod")

build_mod() {            # module name (deps already in $B/mod)
  local m="$1"; mkdir -p "$B/src/$m"
  for f in "$FW/Sources/$m"/*.swift; do strip "$f" > "$B/src/$m/$(basename "$f")"; done
  "$SWIFTC" "${EMB[@]}" -emit-module \
    -emit-module-path "$B/mod/$m.swiftmodule" -module-name "$m" \
    -c "$B/src/$m"/*.swift -o "$B/mod/$m.o"
}

echo "→ framework modules (dependency order)"
for m in SpriteKit AppKit UIKit AVFoundation; do echo "  $m"; build_mod "$m"; done

echo "→ game module"
# NB: no -swift-version 5 here (matches BossMan's embedded build). Under Embedded
# the stack is single-threaded/nonisolated and @MainActor is stripped, so the
# Swift 6 global-concurrency checks that force .v5 in the normal SwiftPM build
# don't apply — and -swift-version 5 + Embedded + -wmo trips a compiler assertion
# (ErrorType canonicalization). Default language mode compiles cleanly.
#
# Embedded Swift has no weak references (no runtime weak machinery). The legacy
# game uses `weak var` IBOutlet-style props and `[weak self]` capture lists, so
# at preprocess time (originals stay untouched) we drop `weak ` -> strong
# capture and delete the now-redundant `guard let self = self else { return }`
# (strong self is always present). Single-threaded, session-length scenes: the
# strong captures are benign (no UAF; at worst a scene lingers a bit longer).
# Embedded-compat source transforms for the legacy game (originals stay untouched):
#  - weak: Embedded has no weak refs. Rewrite [weak X] -> [X = Optional(X)] (strong
#    optional: bodies' `guard let X = X` / `X?.` compile unchanged); `weak var` ->
#    `var` (the T!/T? type keeps the optionality the code relies on).
#  - CIFilter: Embedded has no Any, so the kit types its params [String: Double];
#    addGlow passes a Float radius -> widen to Double (valid natively too).
#  - DispatchQueue.main -> .shared: the literal name DispatchQueue.main makes the
#    compiler infer @MainActor on the submitted closure (GCD special-case); Embedded
#    has no MainActor type, so that asserts in SILGen. The kit vends the same queue
#    as DispatchQueue.shared.
#  - userData casts: tile userData values are the kit's NSMutableDictionary.Value
#    enum (no Any/dynamic-cast in Embedded). Rewrite subscript-result casts to typed
#    accessors. The leading `]` keys on dictionary subscripts, so class downcasts
#    (node as? SKSpriteNode) are left untouched.
strip_game() {
  strip "$1" \
    | perl -pe 's/\[\s*weak\s+(\w+)\s*\]/[$1 = Optional($1)]/g' \
    | sed -e 's/weak var /var /g' -e 's/weak let /let /g' \
    | sed -e 's/"inputRadius":radius/"inputRadius":Double(radius)/' \
    | sed -e 's/DispatchQueue\.main/DispatchQueue.shared/g' \
    | sed -e 's/\] as? Bool/]?.boolValue/g' \
          -e 's/\] as! String/]?.stringValue ?? ""/g' \
          -e 's/\] as? String/]?.stringValue/g' \
          -e 's/\] as? UInt32/]?.uint32Value/g' \
          -e 's/\] as? Double/]?.doubleValue/g'
}
mkdir -p "$B/src/game"; for f in "$GAMESRC"/*.swift; do strip_game "$f" > "$B/src/game/$(basename "$f")"; done
"$SWIFTC" "${EMB[@]}" -module-name UFOEmoji -c "$B/src/game"/*.swift -o "$B/mod/game.o"

echo "→ embedded runtime stubs (sb64 strtod / _initialize ctors / conformance)"
"$CLANG" --target=wasm32-wasi -Os -c "$FW/embedded/embedded-stubs.c" -o "$B/stubs.o"

echo "→ Box2D v3 (pure C) with -ffunction-sections (so --gc-sections strips unused joints/etc)"
mkdir -p "$B/box2d"; B2D="$FW/Sources/CBox2D"
for f in "$B2D"/src/*.c; do
  "$CLANG" --target=wasm32-unknown-wasip1 --sysroot="$SDK/WASI.sdk" -std=c17 -Os -DNDEBUG \
    -ffunction-sections -fdata-sections -I "$B2D/include" -c "$f" -o "$B/box2d/$(basename "$f").o"
done

echo "→ link (Swift + KitABI shim + Box2D v3 + embedded stdlib + WASI libc), --gc-sections"
SHIM="$ROOT/ufo-emoji-web/.build/wasm32-unknown-wasip1/release/KitABI.build/shim.c.o"
[ -f "$SHIM" ] || { echo "ERROR: KitABI shim.c.o not found — run ufo-emoji-web/build.sh release first"; exit 1; }
"$WASMLD" --no-entry --gc-sections --export=boot --export=frame --export=_initialize --export=memory --allow-undefined \
  -L "$SYSLIB" -o "$B/ufoemoji-embedded.wasm" \
  "$B"/mod/*.o "$SHIM" "$B"/box2d/*.o "$B/stubs.o" "$UNI" -lc -lm

wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int --enable-sign-ext \
  --enable-mutable-globals --enable-multivalue "$B/ufoemoji-embedded.wasm" -o "$B/ufoemoji-embedded-oz.wasm"

# Publish next to the normal web payload so CI (and the website deploy) can grab it.
OUT="$ROOT/ufo-emoji-web/web/ufoemoji-embedded.wasm"
cp "$B/ufoemoji-embedded-oz.wasm" "$OUT"

raw=$(stat -f%z "$OUT"); gz=$(gzip -c -9 "$OUT" | wc -c | tr -d ' ')
echo
echo "✓ Embedded UFO Emoji wasm: $raw bytes (-Oz), $gz gzip"
echo "  Normal full-game baseline: 14291860 raw / 4338386 gzip"
echo "  out: $OUT"
echo "  Boot: copy it as ufoemoji.wasm next to runtime-embedded.js + assets, serve over HTTP."
