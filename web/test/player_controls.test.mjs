import assert from 'node:assert/strict';
import { test } from 'node:test';
import vm from 'node:vm';
import { build } from 'esbuild';

const bundle = await build({
  entryPoints: [new URL('../src/artplayer_adapter.ts', import.meta.url).pathname],
  bundle: true, write: false, format: 'cjs', platform: 'node',
  plugins: [{ name: 'player-shell', setup(builder) {
    builder.onResolve({ filter: /^(artplayer|\.\/plugins|\.\/stream_types)$/ }, ({ path }) => ({ path, namespace: 'player-shell' }));
    builder.onLoad({ filter: /.*/, namespace: 'player-shell' }, ({ path }) => ({ contents:
      path === 'artplayer' ? 'export default class Artplayer {}' :
      path === './plugins' ? 'export const ART_PLUGIN_KEYS=[]; export const getPluginInstance=()=>null; export const resolveArtPlugins=async()=>[];' :
      `export const inferStreamType=(url)=>url.endsWith('.m3u8')?'m3u8':'';
       export const buildStreamCustomType=(existing,http)=>({...existing, requestHeaders:http?.headers});`,
    }));
  }}],
});

function player() {
  const module = { exports: {} };
  const classes = new Set();
  let styles = 0;
  vm.runInNewContext(bundle.outputFiles[0].text, { module, exports: module.exports,
    document: { createElement: () => ({ remove() { styles--; } }), head: { appendChild() { styles++; } } },
  });
  const adapter = Object.create(module.exports.KineticArtplayerAdapter.prototype);
  const calls = [];
  const events = {};
  adapter.art = { option: { type: 'm3u8' }, video: {}, on: (name, fn) => { events[name] = fn; },
    reset() { calls.push('reset'); }, async switchUrl(url) { calls.push(url); },
    async play() { calls.push('play'); }, destroy() {}, playing: false,
  };
  adapter.config = { onStateChanged() {}, container: { classList: { add: (name) => classes.add(name), remove: (name) => classes.delete(name) } } };
  adapter.state = 0; adapter.playlist = []; adapter.playlistIndex = 0;
  adapter.autoPlayNext = true; adapter.disposed = false;
  adapter.httpOptions = { headers: { Authorization: 'test-only' } };
  adapter.customTypeOverrides = { custom: 'host-handler' };
  return { adapter, calls, events, classes, styles: () => styles };
}

test('manual next remains usable after automatic advance is disabled', async () => {
  const { adapter, calls } = player();
  await adapter.setPlaylist(['first.mp4', 'second.mp4'], 0, false);
  assert.equal(calls.includes('play'), false);
  adapter.setAutoPlayNext(false);
  assert.equal(await adapter.playNext(), true);
  assert.deepEqual(calls.slice(-2), ['second.mp4', 'play']);
  assert.equal(await adapter.playNext(), false);
});

test('switch from HLS to progressive clears stale type and preserves host handlers/headers', async () => {
  const { adapter } = player();
  await adapter.switchVideoSource('movie.mp4', false);
  assert.equal(adapter.art.option.type, '');
  assert.equal(adapter.art.option.customType.custom, 'host-handler');
  assert.equal(adapter.art.option.customType.requestHeaders.Authorization, 'test-only');
});

test('invalid playlist cannot overwrite the active source', async () => {
  const { adapter, calls } = player();
  await assert.rejects(adapter.setPlaylist(['first.mp4'], 2, true));
  assert.deepEqual(calls, []);
});

test('browser loop owns replay and completion only advances non-looping playlists', async () => {
  const { adapter, calls, events } = player();
  adapter.bindEvents();
  adapter.setLooping(true);
  assert.equal(adapter.art.video.loop, true);
  events['video:ended']();
  assert.deepEqual(calls, []);
  adapter.setLooping(false);
  await adapter.setPlaylist(['one.mp4', 'two.mp4'], 0, false);
  events['video:ended']();
  await new Promise(setImmediate);
  assert.equal(calls.includes('two.mp4'), true);
});

test('repeated control hiding keeps one style and disposal cleans it up', () => {
  const { adapter, styles } = player();
  adapter.hideNativeChrome(); adapter.hideNativeChrome();
  assert.equal(styles(), 1);
  adapter.dispose();
  assert.equal(styles(), 0);
});
