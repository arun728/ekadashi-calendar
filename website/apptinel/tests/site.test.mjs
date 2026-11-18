import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const publicDir = new URL('../public/', import.meta.url);

const pages = [
  '',
  'ekadashi-calendar/',
  'ekadashi-calendar/privacy-policy/',
  'ekadashi-calendar/terms-of-service/',
];

function read(path) {
  return readFileSync(new URL(path, publicDir), 'utf8');
}

for (const path of pages) {
  test('/' + path + ' has a dark default, theme switch, favicon and canonical URL', () => {
    const html = read(path + 'index.html');
    assert.match(html, /<html lang="en" data-theme="dark"/);
    assert.match(html, /<button[^>]+data-theme-toggle/);
    assert.equal((html.match(/<h1[ >]/g) || []).length, 1);
    assert.ok(html.includes('rel="canonical" href="https://apptinel.com/' + path + '"'));
    const icon = html.match(/rel="icon" href="([^"]+)"/);
    assert.ok(icon && existsSync(new URL(icon[1].slice(1), publicDir)));
    assert.match(html, /href="#main"/);
    for (const [, url] of html.matchAll(/(?:href|src)="(\/[^"]*)"/g)) {
      assert.ok(existsSync(new URL(url.slice(1) + (url.endsWith('/') ? 'index.html' : ''), publicDir)), url);
    }
  });
}

test('the product introduction and legal pages describe both platforms', () => {
  const home = read('ekadashi-calendar/index.html');
  for (const item of ['2026 and 2027', 'Smarta', 'Vaishnava', '34,152', 'Lock Screen', 'iPad', 'Monthly', 'Yearly', 'Lifetime', 'Gujarati', 'Bengali']) {
    assert.ok(home.includes(item), item);
  }
  const privacy = read('ekadashi-calendar/privacy-policy/index.html');
  assert.match(privacy, /Firestore/);
  assert.match(privacy, /Limited Use/);
  const terms = read('ekadashi-calendar/terms-of-service/index.html');
  assert.match(terms, /Auto-renew/i);
  assert.match(terms, /Restore Purchases/);
  for (const html of [home, privacy, terms]) {
    assert.match(html, /Google Play/);
    assert.match(html, /Android/);
  }
});

test('the iOS page offers the full shared city and time-zone catalog', () => {
  const home = read('ekadashi-calendar/index.html');
  assert.match(home, /data-catalog="\/assets\/locations.json"/);
  assert.match(home, /src="\/assets\/locations.js"/);
  assert.match(home, /id="zone-filter"/);
  assert.match(home, /தமிழ்/);
  const catalog = JSON.parse(read('assets/locations.json'));
  assert.equal(catalog.release, '2026b');
  assert.equal(catalog.cities.length, 34152);
  assert.equal(catalog.zones.length, 554);
  assert.ok(catalog.zones.includes('Pacific/Chatham'));
});

function themeSession(value, failWrites = false) {
  const attrs = {};
  const button = {
    setAttribute(key, value) { attrs[key] = value; },
    addEventListener(event, fn) { this[event] = fn; },
  };
  const document = {
    documentElement: { dataset: { theme: 'dark' } },
    querySelector: () => button,
    addEventListener(event, fn) { this[event] = fn; },
  };
  const localStorage = {
    value,
    getItem() { return this.value; },
    setItem(key, value) {
      if (failWrites) throw Error('storage unavailable');
      this.value = value;
    },
  };
  runInNewContext(read('assets/theme.js'), { document, localStorage });
  document.DOMContentLoaded();
  return { localStorage, root: document.documentElement, button, attrs };
}

test('modes default to dark, toggle in both directions and persist', () => {
  const session = themeSession(null);
  assert.equal(session.root.dataset.theme, 'dark');
  assert.equal(session.attrs['aria-pressed'], 'false');
  session.button.click();
  assert.equal(session.root.dataset.theme, 'light');
  assert.equal(session.attrs['aria-pressed'], 'true');
  assert.equal(themeSession(session.localStorage.value).root.dataset.theme, 'light');
  session.button.click();
  assert.equal(session.localStorage.value, 'dark');
  assert.equal(session.root.dataset.theme, 'dark');
});

test('invalid preferences and unavailable storage leave the switch usable', () => {
  const session = themeSession('sepia', true);
  assert.equal(session.root.dataset.theme, 'dark');
  session.button.click();
  assert.equal(session.root.dataset.theme, 'light');
});

test('the studio homepage uses one logo and displays the 2026 copyright', () => {
  const home = read('index.html');
  assert.doesNotMatch(home, /class="studio-art"|apptinel-logo\.jpg/);
  assert.equal((home.match(/<img[^>]*apptinel-icon\.png/g) || []).length, 1);
  assert.match(home, /rel="icon" href="\/assets\/apptinel-icon\.png"/);
  assert.match(home, /© 2026 Apptinel Software Private Limited/);
});

test('the Ekadashi hero presents a silent looping preview with playback controls', () => {
  const home = read('ekadashi-calendar/index.html');
  const video = home.match(/<video[^>]+>/);
  assert.ok(video);
  for (const attribute of ['controls', 'muted', 'loop', 'playsinline', 'poster']) {
    assert.ok(video[0].includes(attribute), attribute);
  }
  assert.match(home, /type="video\/mp4"/);
  assert.doesNotMatch(home, /ekadashi-home\.jpg/);
  assert.match(home, /aria-label="Ekadashi Calendar app preview"/);
  assert.match(home, /<figcaption>2027 app preview/);
});

test('the Ekadashi pages have a dedicated readable type system', () => {
  const css = read('assets/site.css');
  assert.match(css, /\.ekadashi h1, \.ekadashi h2\s*\{[^}]*font-family: Lora/);
  assert.match(css, /\.ekadashi\s*\{[^}]*font-family: 'Source Sans 3'/);
  for (const file of ['lora.woff2', 'source-sans-3.woff2']) {
    assert.ok(existsSync(new URL('assets/fonts/' + file, publicDir)));
  }
});

test('every page has copyright and the product provides platform availability', () => {
  for (const path of pages) assert.match(read(path + 'index.html'), /© 2026 Apptinel Software Private Limited/);
  const home = read('ekadashi-calendar/index.html');
  assert.match(home, /https:\/\/play.google.com\/store\/apps\/details\?id=com.applausestudios.ekadashi_calendar/);
  assert.match(home, /iOS · Coming soon/);
  assert.match(home, /Android 7.0/);
});
