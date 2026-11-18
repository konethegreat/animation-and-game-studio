import assert from 'node:assert/strict';
import { resolve } from 'node:path';

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const url = process.env.CREATOR_URL || 'http://localhost:5200/animation-and-game-studio/creator-probe.html';
const screenshots = process.argv[2];
const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  for (const viewport of [{ width: 1440, height: 1000 }, { width: 390, height: 844 }]) {
    const page = await browser.newPage({ viewport, reducedMotion: 'reduce' });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('response', response => {
      if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`);
    });
    const home = new URL('./', url).href;
    assert.equal((await page.goto(home)).status(), 200);
    const link = page.locator('a:visible').filter({ hasText: /^Creator beta$/ }).first();
    assert.equal(await link.getAttribute('data-link'), null);
    await link.click();
    await page.waitForURL(url);
    await page.waitForFunction(() => Boolean(window.__probe?.scene.getObjectByName('hair')), null, { timeout: 120000 });
    assert.match(await page.title(), /beta/i);
    assert.match(await page.locator('.probe-intro').innerText(), /mouth and expressions are unfinished/i);
    const geometry = await page.evaluate(() => {
      const body = window.__probe.scene.getObjectByName('body_mesh');
      return { names: Object.keys(body.morphTargetDictionary), normals: body.geometry.morphAttributes.normal.length };
    });
    assert.ok(geometry.names.includes('feat_portrait_b'));
    assert.ok(!geometry.names.some(name => name.startsWith('ref_')));
    assert.equal(geometry.normals, geometry.names.length);
    assert.equal(await page.getByText(/Reference (woman|man)/).count(), 0);
    const looks = await page.locator('#probe-looks button').allTextContents();
    assert.ok(looks.includes('Portrait B'));
    for (const name of looks) {
      await page.locator('#probe-looks').getByRole('button', { name, exact: true }).click();
      const selected = await page.locator('#probe-looks .is-active').innerText();
      assert.equal(selected, name);
    }
    await page.locator('#probe-looks').getByRole('button', { name: 'Portrait B', exact: true }).click();
    for (const name of ['Face', 'Skin', 'Art', 'Hair and eyes', 'Body']) {
      await page.getByRole('tab', { name, exact: true }).click();
      const slider = page.locator('.probe-tab-panel:not([hidden]) input[type="range"]').first();
      const before = await page.evaluate(() => JSON.stringify(window.__probe.store.get()));
      for (const bound of ['min', 'max']) {
        await slider.fill(await slider.getAttribute(bound));
        await slider.dispatchEvent('input');
      }
      assert.notEqual(await page.evaluate(() => JSON.stringify(window.__probe.store.get())), before, `${name} slider must update state`);
    }
    await page.locator('#probe-looks').getByRole('button', { name: 'Portrait B', exact: true }).click();
    await page.getByRole('button', { name: 'Face', exact: true }).first().click();
    for (const name of ['asset notices', 'license']) {
      const path = await page.getByRole('link', { name, exact: true }).getAttribute('href');
      const response = await page.request.get(new URL(path, url).href);
      assert.equal(response.status(), 200);
      assert.match(await response.text(), /Apache/);
    }
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'No horizontal page overflow');
    await page.evaluate(async () => {
      let previous = '';
      let stable = 0;
      for (let frame = 0; frame < 300; frame++) {
        await new Promise(requestAnimationFrame);
        const p = window.__probe;
        const current = [...p.camera.position.toArray(), p.camera.fov].map(value => value.toFixed(6)).join(',');
        stable = current === previous ? stable + 1 : 0;
        previous = current;
        if (stable >= 5) return;
      }
      throw new Error('Camera did not settle');
    });
    await page.locator('.probe-panel').evaluate(panel => { panel.scrollTop = 0; });
    await page.locator('#probe-view').scrollIntoViewIfNeeded();
    if (screenshots) await page.screenshot({ path: resolve(screenshots, `creator-beta-${viewport.width}.png`), fullPage: true });
    await page.getByRole('link', { name: 'Kone Studio home', exact: true }).click();
    await page.waitForURL(home);
    const game = await page.goto(new URL('play/011-bin-city/', home).href);
    assert.equal(game.status(), 200);
    const frame = page.locator('iframe[title*="BIN CITY"]');
    assert.equal(await frame.count(), 1);
    const gameUrl = new URL(await frame.getAttribute('src'), home).href;
    assert.equal((await page.request.get(gameUrl)).status(), 200);
    await page.frameLocator('iframe[title*="BIN CITY"]').locator('canvas').waitFor({ state: 'attached', timeout: 120000 });
    assert.deepEqual(errors, []);
    console.log(`PASS: ${viewport.width}px creator controls, rights, notices, navigation and Bin City shell`);
    await page.close();
  }
} finally {
  await browser.close();
}
