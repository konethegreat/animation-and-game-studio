import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const url = process.env.CREATOR_URL || 'http://localhost:5200/animation-and-game-studio/creator-probe.html';
const timeout = 8000;
let browser;
before(async () => { browser = await chromium.launch({ channel: 'chrome', headless: true }); });
after(async () => { await browser?.close(); });

async function open(t, abortInitialHair = false) {
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 }, reducedMotion: 'reduce' });
  page.setDefaultTimeout(timeout);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  t.after(async () => { await page.close(); });
  if (abortInitialHair) await page.route('**/models/probe/hair/*.bin', route => route.abort('failed'), { times: 1 });
  await page.goto(url);
  await page.waitForFunction(() => Boolean(window.__probe), null, { timeout: 120000 });
  if (!abortInitialHair) await page.waitForFunction(() => Boolean(window.__probe.character.getObjectByName('hair')));
  return { page, errors };
}

async function state(page) {
  return page.evaluate(() => window.__probe.store.get());
}

async function upload(page, value, name = 'character.json', raw = false) {
  // Wait for the actual file-input handler, not a direct store replacement.
  const handled = page.evaluate(timeout => new Promise((resolve, reject) => {
    const note = document.querySelector('#probe-file-note');
    const observer = new MutationObserver(() => {
      clearTimeout(deadline);
      observer.disconnect();
      resolve(note.textContent);
    });
    const deadline = setTimeout(() => {
      observer.disconnect();
      reject(new Error('Import produced no status update'));
    }, timeout);
    observer.observe(note, { childList: true, characterData: true, subtree: true });
  }), timeout);
  await page.locator('#probe-import-file').setInputFiles({
    name, mimeType: 'application/json', buffer: Buffer.from(raw ? value : JSON.stringify(value)),
  });
  await handled;
}

async function choose(page, kind, id) {
  await page.locator('#probe-tabs [data-tab="hair"]').click();
  await page.locator(`${kind === 'hair' ? '#probe-styles' : '#probe-beards'} [data-id="${id}"]`).click();
}

async function snapshot(page, kind) {
  return page.evaluate(kind => {
    const mesh = window.__probe.character.getObjectByName(kind);
    return mesh ? { uuid: mesh.uuid, follow: [...mesh.material.uniforms.uFollow.value.elements] } : null;
  }, kind);
}

async function changed(page, kind, previous) {
  await page.waitForFunction(({ kind, previous }) => {
    const mesh = window.__probe.character.getObjectByName(kind);
    return mesh && mesh.uuid !== previous;
  }, { kind, previous });
}

async function rendered(page) {
  const frame = await page.evaluate(() => window.__probe.renderer.info.render.frame);
  await page.waitForFunction(frame => window.__probe.renderer.info.render.frame > frame + 1, frame);
}

const assetPattern = id => `**/models/probe/hair/${id}.bin`;
const assetMatches = id => request => new URL(request.url()).pathname.endsWith(`/hair/${id}.bin`);

async function asset(page, id) {
  const response = await page.request.get(new URL(`models/probe/hair/${id}.bin`, url).href);
  assert.ok(response.ok(), `Fixture asset ${id} must be available`);
  const buffer = await response.body();
  const strands = buffer.readUInt32LE(0);
  const points = buffer.readUInt32LE(4);
  const offset = 8 + strands + ((4 - strands % 4) % 4) + points * 24;
  const length = buffer.readUInt32LE(offset);
  const meta = JSON.parse(buffer.subarray(offset + 4, offset + 4 + length).toString());
  return { buffer, follow: meta.follow };
}

async function assertFollow(page, kind, follow) {
  const { actual, expected } = await page.evaluate(({ kind, follow }) => {
    const p = window.__probe;
    const body = p.character.getObjectByName('body_mesh');
    const sum = Array(12).fill(0);
    for (const [name, affine] of Object.entries(follow)) {
      const weight = body.morphTargetInfluences[body.morphTargetDictionary[name]] || 0;
      affine.forEach((value, i) => { sum[i] += value * weight; });
    }
    // THREE.Matrix4 stores the fitted row-major affine in column-major order.
    const expected = [1 + sum[0], sum[4], sum[8], 0, sum[1], 1 + sum[5], sum[9], 0,
      sum[2], sum[6], 1 + sum[10], 0, sum[3], sum[7], sum[11], 1];
    return { actual: [...p.character.getObjectByName(kind).material.uniforms.uFollow.value.elements], expected };
  }, { kind, follow });
  assert.ok(actual.every((value, i) => Math.abs(value - expected[i]) < 1e-8),
    `${kind} must use the active asset's follow metadata, including cache hits`);
}

async function neutral(page) {
  const current = await state(page);
  current.body = { type: 'male', height: 1 };
  current.expression = 'neutral';
  current.morphs = { feat_portrait_b: 0.5 };
  current.hair.style = 'shaved';
  current.hair.beard = 'none';
  await upload(page, current);
  await page.waitForFunction(() => {
    const p = window.__probe;
    const body = p.character.getObjectByName('body_mesh');
    return body.morphTargetInfluences[body.morphTargetDictionary.build_male] === 1 &&
      body.morphTargetInfluences[body.morphTargetDictionary.feat_portrait_b] === 0.5 &&
      !p.character.getObjectByName('hair') && !p.character.getObjectByName('beard');
  });
}

// Routing delays the real binary, leaving parsing, mesh construction and UI untouched.
async function hold(page, id) {
  const ready = Promise.withResolvers();
  await page.route(assetPattern(id), route => { ready.resolve(route); }, { times: 1 });
  return ready.promise;
}

async function release(page, route, buffer) {
  const finished = page.waitForEvent('requestfinished', request => request.url() === route.request().url());
  await route.fulfill({ status: 200, contentType: 'application/octet-stream', body: buffer });
  await finished;
  await rendered(page);
}

test('JSON imports reject non-characters without replacing the current character', async t => {
  const { page, errors } = await open(t);
  const original = await state(page);
  const invalid = [null, [], 'character', 42, {}, { version: 1 }, { ...original, version: 2 },
    { ...original, version: '1' }, { ...original, body: null }, { ...original, skin: [] },
    { ...original, hair: 'afro' }, { ...original, eyes: false }, { ...original, morphs: [] },
    { ...original, outfit: null }, { ...original, version: undefined }];
  for (const [index, value] of invalid.entries()) {
    await t.test(`reject invalid document ${index}`, async () => {
      await upload(page, original, `restore-${index}.json`);
      await page.waitForFunction(name => document.querySelector('#probe-file-note').textContent === `Loaded ${name}`, `restore-${index}.json`);
      await upload(page, value, `invalid-${index}.json`);
      await rendered(page);
      assert.match(await page.locator('#probe-file-note').textContent(), /not a character/i);
      const expected = { ...original, look: null };
      assert.deepEqual(await state(page), expected, 'Rejected import must not reset any choices');
    });
  }
  await t.test('reject malformed JSON', async () => {
    const before = await state(page);
    await upload(page, '{', 'malformed.json', true);
    await rendered(page);
    assert.match(await page.locator('#probe-file-note').textContent(), /not a character/i);
    assert.deepEqual(await state(page), before);
  });
  assert.deepEqual(errors, [], 'Import errors must be handled');
});

test('version 1 partial fields retain sanitization and procedural controls', async t => {
  const { page } = await open(t);
  await upload(page, {
    version: 1, body: { height: 99 }, skin: {}, eyes: {}, hair: { style: '../invalid' },
    morphs: { feat_lips: 99, ref_f_1: 1, unknown: 1 },
  });
  await page.waitForFunction(() => document.querySelector('#probe-file-note').textContent === 'Loaded character.json');
  const current = await state(page);
  assert.equal(current.body.height, 1.08);
  assert.equal(current.hair.style, 'afro');
  assert.equal(current.morphs.feat_lips, 1);
  assert.equal(current.morphs.unknown, undefined);
  assert.equal(current.morphs.ref_f_1, undefined, 'Private reference morphs must not import');
  assert.equal(await page.locator('[id^="morph-ref_"]').count(), 0, 'No reference sliders in the public beta');
  assert.equal(await page.locator('#morph-feat_lips').count(), 1, 'Keep valid procedural sliders');
});

test('initial hair failure is visible outside the Hair tab and can retry', async t => {
  const { page, errors } = await open(t, true);
  await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).waitFor();
  const id = (await state(page)).hair.style;
  await choose(page, 'hair', id);
  await changed(page, 'hair');
  assert.equal(await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).count(), 0);
  assert.deepEqual(errors, [], 'Startup must not leak a rejected readiness promise');
});

for (const [kind, id] of [['hair', 'puff'], ['beard', 'beard_goatee']]) {
  test(`${kind}: abort, visible failure, and retry the same selected choice`, async t => {
    const { page, errors } = await open(t);
    const before = await snapshot(page, kind);
    await page.route(assetPattern(id), route => route.abort('failed'), { times: 1 });
    const failed = page.waitForEvent('requestfailed', assetMatches(id));
    await choose(page, kind, id);
    await failed;
    await t.test('failure is visible and preserves the previous mesh', async () => {
      await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).waitFor();
      assert.deepEqual(await snapshot(page, kind), before);
    });
    await t.test('clicking the same choice issues a fresh request and applies it', async () => {
      const retry = page.waitForRequest(assetMatches(id));
      await choose(page, kind, id);
      await retry;
      await changed(page, kind, before?.uuid);
      assert.equal(await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).count(), 0);
    });
    assert.deepEqual(errors, [], 'Failed downloads must not escape as unhandled rejections');
  });
}

for (const [kind, first, second] of [['hair', 'puff', 'coils'], ['beard', 'beard_goatee', 'beard_full']]) {
  test(`${kind}: cached switching restores the matching fit`, async t => {
    const { page, errors } = await open(t);
    await neutral(page);
    const a = await asset(page, first);
    const b = await asset(page, second);
    await choose(page, kind, first);
    await changed(page, kind);
    const firstMesh = await snapshot(page, kind);
    await assertFollow(page, kind, a.follow);
    await choose(page, kind, second);
    await changed(page, kind, firstMesh.uuid);
    await assertFollow(page, kind, b.follow);
    await choose(page, kind, first);
    await page.waitForFunction(({ kind, uuid }) => window.__probe.character.getObjectByName(kind)?.uuid === uuid,
      { kind, uuid: firstMesh.uuid });
    await assertFollow(page, kind, a.follow);
    assert.deepEqual(errors, []);
  });

  test(`${kind}: stale completion cannot replace the winning mesh or fit`, async t => {
    const { page, errors } = await open(t);
    await neutral(page);
    const late = await asset(page, first);
    const winner = await asset(page, second);
    const held = hold(page, first);
    await choose(page, kind, first);
    const route = await held;
    await choose(page, kind, second);
    await changed(page, kind);
    const winningMesh = await snapshot(page, kind);
    await assertFollow(page, kind, winner.follow);
    await release(page, route, late.buffer);
    assert.deepEqual(await snapshot(page, kind), winningMesh, 'Stale responses must not mutate active follow uniforms');
    await assertFollow(page, kind, winner.follow);
    assert.deepEqual(errors, []);
  });

  test(`${kind}: returning to the applied choice cancels a pending choice`, async t => {
    const { page, errors } = await open(t);
    await neutral(page);
    await choose(page, kind, first);
    await changed(page, kind);
    const original = await snapshot(page, kind);
    const late = await asset(page, second);
    const held = hold(page, second);
    await choose(page, kind, second);
    const route = await held;
    await choose(page, kind, first);
    await release(page, route, late.buffer);
    assert.deepEqual(await snapshot(page, kind), original);
    assert.deepEqual(errors, []);
  });

  test(`${kind}: returning to the applied choice clears a failed choice's error`, async t => {
    const { page, errors } = await open(t);
    const current = await state(page);
    const id = kind === 'hair' ? current.hair.style : current.hair.beard;
    const original = await snapshot(page, kind);
    await page.route(assetPattern(first), route => route.abort('failed'), { times: 1 });
    await choose(page, kind, first);
    await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).waitFor();
    await choose(page, kind, id);
    assert.equal(await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).count(), 0);
    assert.deepEqual(await snapshot(page, kind), original);
    assert.deepEqual(errors, []);
  });

  test(`${kind}: stale failure cannot report an error for a newer choice`, async t => {
    const { page, errors } = await open(t);
    await neutral(page);
    const held = hold(page, first);
    await choose(page, kind, first);
    const route = await held;
    await choose(page, kind, second);
    await changed(page, kind);
    const winningMesh = await snapshot(page, kind);
    const failed = page.waitForEvent('requestfailed', assetMatches(first));
    await route.abort('failed');
    await failed;
    await rendered(page);
    assert.deepEqual(await snapshot(page, kind), winningMesh);
    assert.equal(await page.getByRole('status').filter({ hasText: /could not load.*retry/i }).count(), 0);
    assert.deepEqual(errors, [], 'Stale failures must also be caught');
  });
}
