import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(process.argv[2] || 'showcase/dist');
const entry = resolve(root, 'creator-probe.html');
assert.ok(existsSync(entry), 'Production output must include the creator entry');
const html = readFileSync(entry, 'utf8');
assert.match(html, /<title>[^<]*beta/i, 'The creator must identify itself as beta');
assert.match(html, /mouth.*expressions/i, 'The beta must disclose its unfinished mouth and expressions');
const scripts = [...html.matchAll(/<script[^>]+src="([^"]+)"/g)];
assert.ok(scripts.length > 0, 'The production creator must have a compiled script');
for (const [, url] of scripts) {
  assert.ok(url.startsWith('/animation-and-game-studio/assets/'), `Unexpected production script: ${url}`);
  assert.ok(existsSync(resolve(root, url.replace('/animation-and-game-studio/', ''))), `Missing production script: ${url}`);
}
console.log('PASS: creator beta entry and compiled scripts exist in the production output');
