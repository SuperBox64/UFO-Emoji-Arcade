// Headless smoke test for the UFO Emoji wasm reactor.
//
// Instantiates web/ufoemoji.wasm with auto-stubbed env + WASI imports (the same
// surface WasmKit's runtime.js / WasmCart provide), then drives the real reactor
// contract: _initialize -> boot -> frame(dt) x N. Synthetic key events are fed
// through evt_poll exactly as the browser runtime encodes them (SFML key codes),
// so this exercises the actual gameplay path — title -> start -> fly + fire -> play —
// and asserts the binary never traps while emitting graphics + audio calls.
//
//   node tools/smoketest.mjs [path-to-wasm]

import fs from 'node:fs';
import path from 'node:path';

const WASM = process.argv[2] || new URL('../web/ufoemoji.wasm', import.meta.url).pathname;
const bytes = fs.readFileSync(WASM);
const module = new WebAssembly.Module(bytes);

// ---- Real asset loading (mirrors runtime.js) -------------------------------
// SKScene/SKReferenceNode/SKEmitterNode(fileNamed:) resolve scene JSON through
// asset_text. Serve the actual generated assets (the manifest's `texts`) so the
// smoke test exercises the REAL scene-graph render path, not an empty scene.
const WEB = new URL('../web', import.meta.url).pathname;
const ASSETS = path.join(WEB, 'assets');
const basenameNoExt = (p) => path.basename(p).replace(/\.[^.]*$/, '');

const texts = new Map();    // name -> string (scene/particle JSON)
const soundNames = new Set();
let imgCounter = 0, sndCounter = 0;
const imgHandles = new Map();  // name -> handle
const handleDims = new Map();  // handle -> {w,h}  (O(1) img_width/img_height)
const sndHandles = new Map();
// Default texture extent. Must be > 0: GameParallax computes
// `interations = round(bounds.width / (texWidth*factor) / factor)` and a zero
// width yields a division-by-zero -> Int(inf) -> a multi-billion-iteration loop.
const DEFAULT_DIM = 64;

let manifest = { fonts: [], images: [], sounds: [], texts: [] };
try { manifest = JSON.parse(fs.readFileSync(path.join(WEB, 'manifest.json'), 'utf8')); } catch {}

const registerText = (relPath) => {
  try {
    const s = fs.readFileSync(path.join(ASSETS, relPath), 'utf8');
    const base = path.basename(relPath);
    texts.set(relPath, s);
    texts.set('assets/' + relPath, s);
    texts.set(base, s);
    texts.set(basenameNoExt(relPath), s);
  } catch {}
};
for (const t of manifest.texts || []) registerText(t);

// Image/sound presence (so asset_exists + img/snd lookups resolve to non-zero
// handles); we don't decode pixels headlessly, but report a default size so the
// scene graph lays out and draws (gfx_draw_image still fires).
const registerImage = (relPath) => {
  const names = [relPath, 'assets/' + relPath, path.basename(relPath), basenameNoExt(relPath)];
  imgCounter += 1;
  handleDims.set(imgCounter, { w: DEFAULT_DIM, h: DEFAULT_DIM });
  for (const n of names) imgHandles.set(n, imgCounter);
  return imgCounter;
};
for (const im of manifest.images || []) registerImage(im);
// Resolve (and lazily register) an image handle for any requested name, so a
// texture the game looks up by name always reports a non-zero size — the real
// browser runtime always has real dimensions; never 0.
const lookupOrRegisterImage = (name) => {
  let h = imgHandles.get(name) ?? imgHandles.get(path.basename(name)) ?? imgHandles.get(basenameNoExt(name));
  if (h === undefined) h = registerImage(name);
  return h;
};
const registerSound = (relPath) => {
  const names = [relPath, 'assets/' + relPath, path.basename(relPath), basenameNoExt(relPath)];
  sndCounter += 1;
  for (const n of names) { sndHandles.set(n, sndCounter); soundNames.add(n); }
};
for (const sd of manifest.sounds || []) registerSound(sd);

// SFML key codes (the ABI's event vocabulary; matches SKInput.SKKey).
const SF = { space: 57, left: 71, right: 72, up: 73, down: 74, one: 27 };
const EVT = { KeyPressed: 5, KeyReleased: 6, MouseDown: 9, MouseUp: 10, MouseMoved: 11 };

let memory = null;
const dv = () => new DataView(memory.buffer);
const u8 = () => new Uint8Array(memory.buffer);
const textDecoder = new TextDecoder();
const textEncoder = new TextEncoder();
// Read a length-counted UTF-8 string from wasm memory (the kit's withUTF8Ptr ABI
// passes ptr + byte length, NOT a NUL-terminated string).
const cstr = (ptr, len) => textDecoder.decode(u8().subarray(ptr, ptr + len));

// Event queue consumed by evt_poll.
const events = [];
const key = (type, sf) => events.push({ type, a: sf, b: 0, c: 0, d: 0 });
// Mouse down/up at a logical (y-down) screen pixel. Button 0 = left. SKView's
// pollEvents reads type 9/10 as {a:button, b:x, c:y, d:clickCount}.
const lastMouse = { x: 0, y: 0 };
const mouseDown = (x, y) => { lastMouse.x = x; lastMouse.y = y; events.push({ type: EVT.MouseDown, a: 0, b: x, c: y, d: 1 }); };
const mouseUp   = (x, y) => { lastMouse.x = x; lastMouse.y = y; events.push({ type: EVT.MouseUp,   a: 0, b: x, c: y, d: 1 }); };

// Call counters so we can assert the game is actually doing work.
const calls = Object.create(null);
const bump = (n) => { calls[n] = (calls[n] | 0) + 1; };

// Build an import object covering every import the module declares. Known-
// meaningful functions get real-ish behavior; everything else is a recording
// no-op that returns 0 (the WasmCart "auto-stub unknown imports" approach).
const env = {};
const wasi = {};

const meaningful = {
  win_width:  () => 1280,
  win_height: () => 720,
  font_by_name: () => 1,            // non-zero font handle so labels bind
  img_by_name: (ptr, len) => lookupOrRegisterImage(cstr(ptr, len)),
  img_width:  (h) => handleDims.get(h)?.w || DEFAULT_DIM,
  img_height: (h) => handleDims.get(h)?.h || DEFAULT_DIM,
  asset_exists: (ptr, len) => {
    const name = cstr(ptr, len);
    const base = path.basename(name);
    return (texts.has(name) || texts.has(base) || imgHandles.has(name) || imgHandles.has(base) ||
            sndHandles.has(name) || sndHandles.has(base)) ? 1 : 0;
  },
  asset_text: (ptr, nlen, bufPtr, cap) => {
    const name = cstr(ptr, nlen);
    const s = texts.get(name) ?? texts.get(path.basename(name));
    if (s === undefined) return -1;               // matches runtime.js "missing"
    const enc = textEncoder.encode(s);
    if (cap > 0 && bufPtr) {
      const n = Math.min(enc.length, cap);
      u8().subarray(bufPtr, bufPtr + n).set(enc.subarray(0, n));
    }
    return enc.length;
  },
  snd_by_name: (ptr, len) => {
    bump('snd_by_name');
    const name = cstr(ptr, len);
    return sndHandles.get(name) || sndHandles.get(path.basename(name)) || 1;
  },
  snd_play:    () => { bump('snd_play'); return 1; },
  snd_status:  () => 0,
  mouse_x: () => lastMouse.x,
  mouse_y: () => lastMouse.y,
  gp_connected: () => 0,
  gfx_clear:     () => bump('gfx_clear'),
  gfx_draw_text: () => bump('gfx_draw_text'),
  gfx_draw_image:() => bump('gfx_draw_image'),
  gfx_fill_rect: () => bump('gfx_fill_rect'),
  gfx_fill_circle:() => bump('gfx_fill_circle'),
  gfx_fill_poly: () => bump('gfx_fill_poly'),
  eng_mixer_create: () => 1,
  eng_player_create: () => 1,
  eng_connect: () => 0,
  evt_poll: (typePtr, aPtr, bPtr, cPtr, dPtr) => {
    const e = events.shift();
    if (!e) return 0;
    const d = dv();
    d.setInt32(typePtr, e.type | 0, true);
    d.setInt32(aPtr, e.a | 0, true);
    d.setInt32(bPtr, e.b | 0, true);
    d.setInt32(cPtr, e.c | 0, true);
    d.setInt32(dPtr, e.d | 0, true);
    return 1;
  },
};

const wasiMeaningful = {
  // wasi-libc reactor init touches a handful of these; success = 0.
  environ_sizes_get: (cntPtr, bufPtr) => { dv().setInt32(cntPtr, 0, true); dv().setInt32(bufPtr, 0, true); return 0; },
  args_sizes_get:    (cntPtr, bufPtr) => { dv().setInt32(cntPtr, 0, true); dv().setInt32(bufPtr, 0, true); return 0; },
  environ_get: () => 0,
  args_get: () => 0,
  random_get: (buf, len) => { const a = u8(); for (let i = 0; i < len; i++) a[buf + i] = (i * 2654435761) & 0xff; return 0; },
  clock_time_get: (id, prec, tptr) => { dv().setBigUint64(tptr, 0n, true); return 0; },
  fd_write: (fd, iovs, n, nwritten) => { dv().setInt32(nwritten, 0, true); return 0; },
  fd_close: () => 0, fd_seek: () => 0, fd_read: () => 0, fd_fdstat_get: () => 0,
  proc_exit: (code) => { throw new Error('proc_exit(' + code + ')'); },
};

for (const imp of WebAssembly.Module.imports(module)) {
  const table = imp.module === 'env' ? env : wasi;
  const known = imp.module === 'env' ? meaningful : wasiMeaningful;
  if (imp.kind !== 'function') continue;
  table[imp.name] = known[imp.name] || (() => { bump(imp.module + '.' + imp.name); return 0; });
}

const instance = new WebAssembly.Instance(module, {
  env,
  wasi_snapshot_preview1: wasi,
});
memory = instance.exports.memory;
const { _initialize, boot, frame } = instance.exports;

function frames(n, dt = 16.6) { for (let i = 0; i < n; i++) frame(dt); }

let phase = 'init';
try {
  _initialize();
  phase = 'boot';
  boot();
  phase = 'title';
  frames(30);                       // title screen renders
  const titleText = calls.gfx_draw_text | 0;

  phase = 'start';
  // The menu starts the game on a TOUCH of the "play"/"playbutton" node (not a
  // key). With the smoke-test viewport (1280x720 -> phone, mode 2) the menu
  // scene is 626x352 anchored at center, and the play button sits at scene
  // (229,-103) -> logical screen pixel (542, 279). Tap it.
  mouseDown(542, 279);
  mouseUp(542, 279);
  frames(20);
  // Menu defers the transition ~1.6s via DispatchQueue.main.asyncAfter, then
  // StartUp's ready-set-go plays before GameScene presents (and plays music).
  frames(200);

  phase = 'play';
  key(EVT.KeyPressed, SF.right);    // thrust right
  key(EVT.KeyPressed, SF.space);    // hold fire
  frames(120);
  key(EVT.KeyPressed, SF.up);       // climb
  frames(120);
  key(EVT.KeyReleased, SF.up);
  key(EVT.KeyReleased, SF.right);
  key(EVT.KeyReleased, SF.space);
  frames(120);

  // simulate a longer run to provoke enemy spawns, collisions, item drops
  for (let i = 0; i < 6; i++) {
    key(EVT.KeyPressed, SF.space);
    frames(60);
    key(EVT.KeyReleased, SF.space);
    frames(40);
  }
  phase = 'done';
} catch (err) {
  console.error(`\n✗ TRAP during phase "${phase}":`, err.message);
  process.exit(1);
}

const need = ['gfx_clear', 'gfx_draw_text', 'snd_play'];
const missing = need.filter((k) => !(calls[k] > 0));

console.log('\nUFO Emoji wasm smoke test');
console.log('  ran _initialize -> boot -> ~970 frames with synthetic input, no trap');
console.log('  draw/text/audio call counts:');
for (const k of ['gfx_clear', 'gfx_draw_text', 'gfx_draw_image', 'gfx_fill_rect', 'gfx_fill_circle', 'snd_play', 'snd_by_name'])
  console.log(`    ${k.padEnd(16)} ${calls[k] | 0}`);

if (missing.length) {
  console.error('\n✗ expected calls never happened:', missing.join(', '));
  process.exit(1);
}
console.log('\n✓ PASS — reactor boots, renders text/sprites, plays sound, survives gameplay input.');
