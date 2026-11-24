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
    assert.match(html, /data-theme-switch/);
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

function themeSession(stored, { osDark = true, failWrites = false } = {}) {
  const buttons = ['light', 'dark'].map((choice) => ({
    choice,
    attrs: {},
    dataset: { themeChoice: choice },
    setAttribute(key, value) { this.attrs[key] = value; },
    addEventListener(event, fn) { this[event] = fn; },
  }));
  const group = { hidden: true };
  const media = {
    matches: osDark,
    listeners: [],
    addEventListener(event, fn) { this.listeners.push(fn); },
    flip(dark) { this.matches = dark; this.listeners.forEach((fn) => fn({ matches: dark })); },
  };
  const document = {
    documentElement: { dataset: { theme: 'dark' } },
    querySelector: () => group,
    querySelectorAll: () => buttons,
    addEventListener(event, fn) { this[event] = fn; },
  };
  const localStorage = {
    value: stored,
    getItem() { return this.value; },
    setItem(key, value) {
      if (failWrites) throw Error('storage unavailable');
      this.value = value;
    },
  };
  const matchMedia = () => media;
  runInNewContext(read('assets/theme.js'), { document, localStorage, matchMedia });
  document.DOMContentLoaded();
  const pick = (choice) => buttons.find((b) => b.choice === choice);
  const checked = () => buttons.filter((b) => b.attrs['aria-checked'] === 'true').map((b) => b.choice);
  return { localStorage, root: document.documentElement, media, group, pick, checked };
}

test('with no saved choice the theme starts from the OS setting and follows it', () => {
  const dark = themeSession(null, { osDark: true });
  assert.equal(dark.root.dataset.theme, 'dark');
  assert.deepEqual(dark.checked(), ['dark']);
  assert.equal(dark.group.hidden, false);
  dark.media.flip(false);
  assert.equal(dark.root.dataset.theme, 'light');
  assert.deepEqual(dark.checked(), ['light']);
  const light = themeSession(null, { osDark: false });
  assert.equal(light.root.dataset.theme, 'light');
  assert.deepEqual(light.checked(), ['light']);
});

test('Light and Dark persist and ignore OS changes', () => {
  const s = themeSession(null, { osDark: true });
  s.pick('light').click();
  assert.equal(s.root.dataset.theme, 'light');
  assert.deepEqual(s.checked(), ['light']);
  assert.equal(s.localStorage.value, 'light');
  s.media.flip(true);
  assert.equal(s.root.dataset.theme, 'light');
  s.pick('dark').click();
  assert.equal(s.root.dataset.theme, 'dark');
  assert.equal(s.localStorage.value, 'dark');
  s.media.flip(false);
  assert.equal(s.root.dataset.theme, 'dark');
  assert.equal(themeSession('dark', { osDark: false }).root.dataset.theme, 'dark');
  assert.equal(themeSession('light', { osDark: true }).root.dataset.theme, 'light');
});

test('an old System choice, invalid values and unavailable storage fall back to the OS setting', () => {
  const old = themeSession('system', { osDark: false });
  assert.equal(old.root.dataset.theme, 'light');
  assert.deepEqual(old.checked(), ['light']);
  const s = themeSession('sepia', { osDark: false, failWrites: true });
  assert.equal(s.root.dataset.theme, 'light');
  s.pick('dark').click();
  assert.equal(s.root.dataset.theme, 'dark');
  assert.deepEqual(s.checked(), ['dark']);
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

test('platform differences cover widgets, permission controls and both store cancellation paths', () => {
  const home = read('ekadashi-calendar/index.html');
  assert.match(home, /Ekadashi Today/);
  assert.match(home, /iOS footage/);
  const privacy = read('ekadashi-calendar/privacy-policy/index.html');
  for (const text of ['Android Auto Backup', 'exact alarms', 'approximate or precise', 'older Android', 'Google Play Billing']) assert.ok(privacy.includes(text), text);
  const terms = read('ekadashi-calendar/terms-of-service/index.html');
  assert.match(terms, /Payments &amp; subscriptions/);
  assert.match(terms, /support.google.com\/googleplay\/answer\/2479637/);
  assert.match(terms, /Uninstalling the app does not cancel/);
});

test('the privacy policy says Firebase Authentication keeps the Google account email', () => {
  const privacy = read('ekadashi-calendar/privacy-policy/index.html');
  assert.match(privacy, /Firebase Authentication keeps the Google account's email address/);
  assert.match(privacy, /The Firestore record itself contains no event content or email address/);
});

for (const path of pages) {
  test('/' + path + ' has a Light / Dark icon switch outside the navigation links, with no System option', () => {
    const html = read(path + 'index.html');
    const nav = html.match(/<nav aria-label="Main navigation">([\s\S]*?)<\/nav>/)[1];
    assert.doesNotMatch(nav, /data-theme/);
    const group = html.match(/<div class="theme-switch" role="radiogroup" aria-label="Theme" data-theme-switch hidden>([\s\S]*?)<\/div>/);
    assert.ok(group, 'theme switch exists');
    assert.doesNotMatch(group[1], /system/i);
    assert.equal((group[1].match(/<button/g) || []).length, 2);
    for (const [choice, label, icon] of [['light', 'Light', 'icon-sun'], ['dark', 'Dark', 'icon-moon']]) {
      const button = group[1].match(new RegExp('<button[^>]+data-theme-choice="' + choice + '"[^>]*>([\\s\\S]*?)</button>'));
      assert.ok(button, choice);
      assert.match(button[0], new RegExp('role="radio"'));
      assert.match(button[0], new RegExp('aria-label="' + label + '"'));
      assert.match(button[1], new RegExp('class="' + icon + '"'));
      assert.doesNotMatch(button[1].replace(/<[^>]+>/g, ''), /\S/, 'icon only');
    }
  });
}

test('the studio products list Ekadashi Calendar and Vault Hub as a private vault, not AI tools or a password manager', () => {
  const home = read('index.html');
  assert.doesNotMatch(home, /AI tools/);
  assert.doesNotMatch(home, /password manager/i);
  const vault = home.match(/<h3>Vault Hub<\/h3>\s*<p>([^<]+)<\/p>/);
  assert.ok(vault, 'Vault Hub card');
  assert.match(vault[1], /end-to-end encrypted/);
  assert.match(vault[1], /Google Drive or iCloud/);
});
