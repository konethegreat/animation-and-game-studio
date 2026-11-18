import assert from 'node:assert/strict';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1000, height: 850 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' && !message.location().url.endsWith('/favicon.ico')) {
      errors.push(`${message.text()} ${message.location().url}`);
    }
  });
  await page.goto(process.env.CREATOR_URL || 'http://localhost:5200/animation-and-game-studio/creator-probe.html');
  await page.waitForFunction(() => Boolean(window.__probe), null, { timeout: 120000 });
  await page.getByRole('button', { name: 'Face', exact: true }).first().click();
  const morphNormals = await page.evaluate(() => {
    const body = window.__probe.scene.getObjectByName('body_mesh');
    const normals = body.geometry.morphAttributes.normal ?? [];
    const portrait = normals[body.morphTargetDictionary.feat_portrait_b];
    return {
      positions: body.geometry.morphAttributes.position.length,
      normals: normals.length,
      portraitChanges: portrait ? Array.from(portrait.array).filter(value => Math.abs(value) > 0.001).length : 0,
    };
  });
  assert.equal(morphNormals.normals, morphNormals.positions, 'Facial shape changes must carry matching lighting normals');
  assert.ok(morphNormals.portraitChanges > 100, 'Portrait B must change surface shading as well as position');
  const skin = await page.evaluate(async () => {
    const p = window.__probe;
    const body = p.scene.getObjectByName('body_mesh');
    if (!body) throw new Error('Character body did not load');
    p.controls.enableDamping = false;
    p.controls.target.set(0, 1.542, 0.06);
    p.camera.position.set(0, 1.567, 1.66);
    p.camera.fov = 15;
    p.camera.updateProjectionMatrix();
    p.controls.update();
    p.scene.environment = null;
    p.scene.background = null;
    p.renderer.setClearColor(0, 1);
    const lights = [];
    p.scene.traverse(object => {
      if (object.isLight) lights.push([object, object.intensity]);
      if (object.isMesh) object.visible = object === body;
    });
    function pixels() {
      p.renderer.render(p.scene, p.camera);
      const gl = p.renderer.getContext();
      const data = new Uint8Array(gl.drawingBufferWidth * gl.drawingBufferHeight * 4);
      gl.readPixels(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight, gl.RGBA, gl.UNSIGNED_BYTE, data);
      return data;
    }
    function brightness(data) {
      let sum = 0;
      let max = 0;
      for (let i = 0; i < data.length; i += 4) {
        sum += data[i] + data[i + 1] + data[i + 2];
        max = Math.max(max, data[i], data[i + 1], data[i + 2]);
      }
      return { mean: sum / (data.length * 0.75), max };
    }
    const dark = [];
    for (const scatter of [0, 1]) {
      p.store.update(state => { state.skin.scatter = scatter; });
      for (const [light] of lights) light.intensity = 0;
      dark.push({ scatter, ...brightness(pixels()) });
    }
    const lit = [];
    for (const scatter of [0, 1]) {
      p.store.update(state => { state.skin.scatter = scatter; });
      for (const [light, intensity] of lights) light.intensity = intensity;
      lit.push(pixels());
    }
    let changed = 0;
    for (let i = 0; i < lit[0].length; i += 4) {
      if (Math.abs(lit[0][i] - lit[1][i]) > 2) changed++;
    }
    return { dark, lit: brightness(lit[0]), changed };
  });
  console.log(JSON.stringify({ skin, errors }, null, 2));
  assert.deepEqual(errors, [], 'Real WebGL shaders must compile without browser errors');
  assert.ok(skin.lit.mean > 5, 'Control: the loaded skin must render under lights');
  for (const result of skin.dark) {
    assert.ok(result.max <= 1, `Skin emitted light without illumination at scatter=${result.scatter}: max=${result.max}`);
  }
  assert.ok(skin.changed > 100, 'Scattering must visibly change lit skin, not become a disconnected slider');
  const eyeWhites = await page.evaluate(() => {
    const p = window.__probe;
    return [0.3, 0.6, 1].map(value => {
      p.store.update(state => { state.eyes.sclera = value; });
      return ['L', 'R'].map(side => p.scene.getObjectByName(`sclera_${side}`).material.color.getHexString());
    });
  });
  assert.deepEqual(eyeWhites, [
    ['4d4a46', '4d4a46'], ['99948d', '99948d'], ['fff6eb', 'fff6eb'],
  ], 'Eye whites must interpret brightness in the same perceptual color space as the eye color picker');
  console.log('PASS: skin requires illumination, scattering remains adjustable, and eye whites use perceptual brightness');
} finally {
  await browser.close();
}
