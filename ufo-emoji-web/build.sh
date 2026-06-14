#!/usr/bin/env bash
# UFO Emoji — SpriteKit→wasm build helper.
#
#   ./build.sh            # debug build
#   ./build.sh release    # release build (-Osize + wasm-opt)
#   ./build.sh assets     # (re)run the .sks/asset pipeline only
#
# Compiles the ORIGINAL 14 game files (symlinked from ../UFO Emoji/UFO Emoji)
# UNCHANGED against the local ../../SuperBox64Kit, converts .sks→JSON via
# sks2json, converts xcassets PDFs→SVG, transcodes audio, regenerates
# manifest.json, and copies WasmKit's runtime.js.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME="$SCRIPT_DIR/../UFO Emoji/UFO Emoji"
WASMKIT="$SCRIPT_DIR/../../WasmKit"
SBK="$SCRIPT_DIR/../../SuperBox64Kit"
SRC="$SCRIPT_DIR/Sources/UFOEmoji"
OUT="$SCRIPT_DIR/web/assets"

SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-org.swift.6.3.2-release}"
WASM_SDK="${WASM_SDK:-swift-6.3.2-RELEASE_wasm}"

# ---- 1. sync original sources (idempotent) ---------------------------------
# Most files are symlinked UNCHANGED from ../UFO Emoji/UFO Emoji. A few need a
# build-time .preCommon transform because they use constructs the wasm target
# cannot express (no Objective-C runtime). The ORIGINALS on disk are NEVER
# edited — we generate transformed COPIES into Sources/UFOEmoji instead.
#
#   * GameScene.swift / GameMenu.swift: `for touch: AnyObject in touches`
#     relies on ObjC dynamic dispatch for `touch.location(in:)`. `touches` is a
#     Set<UITouch>, so dropping the explicit `: AnyObject` binds `touch` to
#     UITouch and `.location(in:)` resolves statically.
#   * GTFlightYoke.swift: `@objc func update()` + `CADisplayLink(target:selector:
#     #selector(update))` require the ObjC runtime. We strip `@objc` and rewrite
#     the display-link construction to the kit's portable closure form
#     `CADisplayLink(every:)`, which drives update() each frame via KitRunLoop.
#   * AppDelegate.swift: its @UIApplicationMain entry point conflicts with our
#     boot() reactor entry, and nothing references the type — so it is EXCLUDED.
#     main.swift calls loadSettings() in its place.
sync_sources() {
  local rel="../../../UFO Emoji/UFO Emoji"
  local base="$GAME"
  # Plain unchanged symlinks.
  local files=(
    "GameScene/Extensions.swift"
    "GameModel/GameTimeMapRun.swift" "GameModel/GameWorld.swift"
    "GameModel/GameBadGuyAI.swift" "GameModel/GameParallax.swift"
    "GameGlobal/GameGlobal.swift"
    "GameTransitions/StartUp.swift" "GameTransitions/LevelUp.swift" "GameTransitions/GameOver.swift"
    "GameViewController/GameViewController.swift"
  )
  mkdir -p "$SRC"
  # Clear out any prior transformed copies so a re-sync can't leave a stale file
  # shadowing a symlink (or vice-versa).
  rm -f "$SRC/GameScene.swift" "$SRC/GameMenu.swift" "$SRC/GTFlightYoke.swift" "$SRC/AppDelegate.swift"
  for f in "${files[@]}"; do ln -sf "$rel/$f" "$SRC/$(basename "$f")"; done

  # .preCommon transforms — transformed COPIES, originals untouched.
  sed 's/for touch: AnyObject in/for touch in/g' \
      "$base/GameScene/GameScene.swift" > "$SRC/GameScene.swift"
  sed 's/for touch: AnyObject in/for touch in/g' \
      "$base/GameMenu/GameMenu.swift" > "$SRC/GameMenu.swift"
  sed -e 's/@objc func update/func update/g' \
      -e 's/CADisplayLink(target: self, selector: #selector(update))/CADisplayLink(every: { [weak self] in self?.update() })/g' \
      "$base/GTFlightYoke/GTFlightYoke.swift" > "$SRC/GTFlightYoke.swift"
}

# ---- 2. asset pipeline -----------------------------------------------------
build_assets() {
  mkdir -p "$OUT/scenes" "$OUT/particles" "$OUT/images" "$OUT/fonts" "$OUT/sfx"

  echo "→ sks2json (.sks → JSON)"
  ( cd "$SBK/Tools/sks2json" && xcrun swift build -c release >/dev/null )
  local s2j="$SBK/Tools/sks2json/.build/release/sks2json"
  "$s2j" --out "$OUT/scenes" "$GAME/GameScene/GameScene.sks" "$GAME/GameMenu/GameMenu.sks" >/dev/null 2>&1 || true
  for n in $(seq 1 12); do "$s2j" --out "$OUT/scenes" "$GAME/GameLevels/level${n}.sks" >/dev/null 2>&1 || true; done
  for p in aura blackHole blueParticle fireParticle magicParticle minigamehole smokeParticle; do
    "$s2j" --out "$OUT/particles" "$GAME/GameParticles/${p}.sks" >/dev/null 2>&1 || true
  done

  echo "→ xcassets PDFs → SVG (vector hi-res; REAL sprite atlases only — placeholders + emoji-tiles skipped, those render as live emoji text)"
  rm -f "$OUT"/images/*.svg "$OUT"/images/*.png 2>/dev/null || true
  # The terrain/UI/effect atlases the game loads via SKTexture(imageNamed:).
  # Emoji-glyph atlases (smileys/people/food/bad-guy-*/…) are NOT converted —
  # the game draws those as SKLabelNode text, so shipping them would just bloat
  # the preload with hundreds of unused images.
  local REAL_ATLASES=(
    GameGrass.spriteatlas GameWater.spriteatlas GameMenu.spriteatlas GameEffects.spriteatlas
    Backgrounds.spriteatlas GameHUD.spriteatlas GameGUI.spriteatlas GameDirt.spriteatlas
    GameStones.spriteatlas GameStraw GameGold
  )
  if command -v mutool >/dev/null 2>&1; then
    for atlas in "${REAL_ATLASES[@]}"; do
      find "$GAME/Assets.xcassets/$atlas" -name '*.pdf' 2>/dev/null | while read -r pdf; do
        base="$(basename "$pdf" .pdf)"
        # mutool appends the page index (foo.svg -> foo1.svg), so write to a temp
        # name and rename to the exact leaf the game's imageNamed: expects.
        mutool convert -o "$OUT/images/__t.svg" "$pdf" 1 >/dev/null 2>&1 || true
        [ -f "$OUT/images/__t1.svg" ] && mv -f "$OUT/images/__t1.svg" "$OUT/images/${base}.svg"
      done
    done
  elif command -v pdf2svg >/dev/null 2>&1; then
    for atlas in "${REAL_ATLASES[@]}"; do
      find "$GAME/Assets.xcassets/$atlas" -name '*.pdf' 2>/dev/null | while read -r pdf; do
        base="$(basename "$pdf" .pdf)"
        pdf2svg "$pdf" "$OUT/images/${base}.svg" 1 >/dev/null 2>&1 || true
      done
    done
  else
    echo "  ⚠️  no mutool/pdf2svg — install: brew install mupdf-tools"
  fi
  # bokeh particle texture is a real raster (soft glow) — copy as-is.
  find "$GAME/Assets.xcassets" -name 'bokeh.png' -exec cp {} "$OUT/images/" \; 2>/dev/null || true

  echo "→ font"
  cp "$GAME/GameFonts/emulogic.ttf" "$OUT/fonts/Emulogic.ttf" 2>/dev/null || true

  echo "→ audio (m4a/mp3 → wav/ogg, registered under requested names)"
  if command -v ffmpeg >/dev/null 2>&1; then
    # Clean single extensions — the runtime strips the query's extension when
    # resolving, so the game's playSoundFileNamed("fire.m4a") finds fire.wav.
    for s in fire wah2 murrmurr boomFire1 boomFire2 Explosion1 extralife doublelaser; do
      [ -f "$GAME/GameSounds/${s}.m4a" ] && ffmpeg -y -i "$GAME/GameSounds/${s}.m4a" "$OUT/sfx/${s}.wav" >/dev/null 2>&1 || true
    done
    # Background music: WASM/Web Audio plays it quieter than the iOS AVAudioPlayer,
    # so boost +8dB for this game's web build ONLY (the Apple asset is untouched).
    if [ -f "$GAME/GameMusic/music1.mp3" ]; then
      ffmpeg -y -i "$GAME/GameMusic/music1.mp3" -filter:a "volume=8dB" -c:a libmp3lame -q:a 4 "$OUT/sfx/music1.mp3" >/dev/null 2>&1 \
        || cp "$GAME/GameMusic/music1.mp3" "$OUT/sfx/music1.mp3" 2>/dev/null || true
    fi
  fi
}

# ---- 3. manifest + runtime -------------------------------------------------
publish_web() {
  # Generate manifest.json directly from what's on disk (full control, SVG-aware).
  # Shape matches runtime.js discoverAssets(): {fonts,images,sounds,texts}. NEVER
  # falls back to WasmKit's hardcoded BossMan defaults because the file always
  # exists. Scenes + particles go under `texts` (resolved via asset_text).
  python3 - "$SCRIPT_DIR/web/manifest.json" "$OUT" <<'PY'
import json, os, sys
man, A = sys.argv[1], sys.argv[2]
def rel(sub, exts):
    d = os.path.join(A, sub)
    return sorted(f"{sub}/{f}" for f in os.listdir(d) if f.endswith(exts)) if os.path.isdir(d) else []
m = {
  "fonts":  rel("fonts",  (".ttf", ".otf")),
  "images": rel("images", (".svg", ".png")),
  "sounds": rel("sfx",    (".wav", ".ogg", ".mp3")),
  "texts":  rel("scenes", (".json",)) + rel("particles", (".json",)),
}
json.dump(m, open(man, "w"))
print(f"  manifest: {len(m['fonts'])} fonts, {len(m['images'])} images, {len(m['sounds'])} sounds, {len(m['texts'])} texts")
PY
  cp "$WASMKIT/runtime.js" "$SCRIPT_DIR/web/runtime.js" 2>/dev/null || true
}

# ---- main ------------------------------------------------------------------
if [ "$1" = "assets" ]; then build_assets; publish_web; echo "✓ assets"; exit 0; fi

sync_sources

CONFIG_ARGS=(-c debug)
[ "$1" = "release" ] && CONFIG_ARGS=(-c release -Xswiftc -Osize -Xlinker -s -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata)

echo "→ swift build (toolchain=$SWIFT_TOOLCHAIN sdk=$WASM_SDK)"
TOOLCHAINS="$SWIFT_TOOLCHAIN" xcrun --toolchain swift swift build --swift-sdk "$WASM_SDK" "${CONFIG_ARGS[@]}"

if [ "$1" = "release" ]; then
  REL=".build/wasm32-unknown-wasip1/release/UFOEmoji.wasm"
  if command -v wasm-opt >/dev/null 2>&1; then
    wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int \
      --enable-sign-ext --enable-mutable-globals --enable-multivalue \
      "$REL" -o web/ufoemoji.wasm
  else cp "$REL" web/ufoemoji.wasm; fi
else
  cp ".build/wasm32-unknown-wasip1/debug/UFOEmoji.wasm" web/ufoemoji.wasm
fi
echo "✓ wasm → web/ufoemoji.wasm"

build_assets
publish_web
echo "✓ build complete"
