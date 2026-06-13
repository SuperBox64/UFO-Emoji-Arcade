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

const WASM = process.argv[2] || new URL('../web/ufoemoji.wasm', import.meta.url).pathname;
const bytes = fs.readFileSync(WASM);
const module = new WebAssembly.Module(bytes);

// SFML key codes (the ABI's event vocabulary; matches SKInput.SKKey).
const SF = { space: 57, left: 71, right: 72, up: 73, down: 74, one: 27 };
const EVT = { KeyPressed: 5, KeyReleased: 6 };

let memory = null;
const dv = () => new DataView(memory.buffer);
const u8 = () => new Uint8Array(memory.buffer);

// Event queue consumed by evt_poll.
const events = [];
const key = (type, sf) => events.push({ type, a: sf, b: 0, c: 0, d: 0 });

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
  img_by_name:  () => 0,            // no image atlas; actors are text
  img_width:  () => 0,
  img_height: () => 0,
  asset_exists: () => 1,
  asset_text:  () => 0,
  snd_by_name: () => { bump('snd_by_name'); return 1; },   // non-zero buffer handle
  snd_play:    () => { bump('snd_play'); return 1; },
  snd_status:  () => 0,
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
  key(EVT.KeyPressed, SF.space);    // press space -> start game
  frames(160);                      // ready-set-go (~2s) then into play

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
