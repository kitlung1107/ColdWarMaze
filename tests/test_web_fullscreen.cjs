// Run with: node tests/test_web_fullscreen.cjs
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const config = fs.readFileSync(path.join(__dirname, '../export_presets.cfg'), 'utf8');
const head = JSON.parse(config.match(/^html\/head_include=(.*)$/m)[1]);
const scripts = [...head.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);

function browser({ua = '', platform = '', maxTouchPoints = 0, request, enabled, standalone = false} = {}) {
  const ids = {}, events = {}, windowEvents = {};
  let document;
  class Element {
    constructor() { this.hidden = false; this.style = {}; this.children = []; this.listeners = {}; }
    set id(value) { ids[value] = this; }
    setAttribute() {}
    append(...children) { this.children.push(...children); }
    replaceChildren() { this.children = []; }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    focus() { document.activeElement = this; }
    click() { return this.listeners.click?.(); }
  }
  document = {
    body: new Element(), documentElement: {requestFullscreen: request}, fullscreenEnabled: enabled,
    createElement: () => new Element(), getElementById: id => ids[id],
    addEventListener: (name, callback) => events[name] = callback,
  };
  const window = {
    addEventListener: (name, callback) => windowEvents[name] = callback,
    dispatchEvent: event => windowEvents[event.type]?.(event),
    matchMedia: () => ({matches: standalone}),
  };
  const context = vm.createContext({document, window,
    navigator: {userAgent: ua, platform, maxTouchPoints},
    Event: class { constructor(type) { this.type = type; } },
  });
  scripts.forEach(script => vm.runInContext(script, context));
  events.DOMContentLoaded();
  const [title, message, steps, enter, install, close] = ids['cw-fullscreen-card'].children;
  return {window, document, windowEvents, events, title, message, steps, enter, install, close};
}
const flush = () => new Promise(resolve => setImmediate(resolve));

(async () => {
  // iPad desktop-mode UA must also avoid Safari native fullscreen.
  for (const device of [{ua: 'iPad'}, {ua: 'iPhone'},
    {ua: 'Mozilla/5.0 (Macintosh)', platform: 'MacIntel', maxTouchPoints: 5}]) {
    let requests = 0;
    const b = browser({...device, enabled: true, request: () => requests++});
    b.window.cwOfferFullscreen();
    assert.equal(b.enter.hidden, true);
    assert.match(b.message.textContent, /輸入提示/);
    b.window.cwRequestFullscreen(); // Includes the in-game pause menu entry.
    assert.equal(requests, 0);
    assert.equal(b.steps.hidden, false);
    assert.match(b.steps.children[0].textContent, /Safari/);
  }
  const mac = browser({platform: 'MacIntel', request() {}});
  mac.window.cwOfferFullscreen();
  assert.equal(mac.enter.hidden, false);
  for (const ua of ['iPhone', 'iPad', 'Android', 'Firefox', 'Other browser']) {
    const b = browser({ua});
    assert.equal(b.window.cwOfferFullscreen(), true);
    assert.equal(b.enter.hidden, true);
    await b.install.click();
    assert.equal(b.steps.hidden, false);
    assert.equal(b.steps.children.length, 3);
    b.close.click();
    assert.equal(b.window.cwFullscreenPromptOpen, false);
    assert.equal(b.window.cwOfferFullscreen(), false);
  }
  const blocked = browser({enabled: false, request: () => { throw Error('Must not request'); }});
  blocked.window.cwOfferFullscreen();
  assert.equal(blocked.enter.hidden, true);
  blocked.window.cwRequestFullscreen();
  assert.equal(blocked.steps.hidden, false);

  for (const outcome of ['accepted', 'dismissed']) {
    const b = browser(); let calls = 0;
    b.windowEvents.beforeinstallprompt({preventDefault() {},
      prompt() { calls++; return Promise.resolve(); }, userChoice: Promise.resolve({outcome})});
    b.window.cwOfferFullscreen();
    await b.install.click();
    assert.equal(calls, 1);
    assert.equal(b.window.cwFullscreenPromptOpen, false);
    assert.equal(b.install.disabled, false);
  }
  const rejectedInstall = browser();
  rejectedInstall.windowEvents.beforeinstallprompt({preventDefault() {}, prompt: () => Promise.reject(Error('Unavailable'))});
  rejectedInstall.window.cwOfferFullscreen();
  await rejectedInstall.install.click();
  assert.equal(rejectedInstall.steps.hidden, false);

  const rejected = browser({request: () => Promise.reject(Error('Denied'))});
  rejected.window.cwOfferFullscreen(); rejected.window.cwRequestFullscreen(); await flush();
  assert.equal(rejected.steps.hidden, false);

  let reject;
  const delayed = browser({request: () => new Promise((_, fail) => { reject = fail; })});
  delayed.window.cwOfferFullscreen(); delayed.window.cwRequestFullscreen(); delayed.close.click();
  reject(Error('Denied')); await flush();
  assert.equal(delayed.window.cwFullscreenPromptOpen, false);

  const success = browser({request() { success.document.fullscreenElement = {}; success.events.fullscreenchange(); }});
  success.window.cwOfferFullscreen(); success.enter.click();
  assert.equal(success.window.cwFullscreenPromptOpen, false);
  assert.equal(browser({standalone: true}).window.cwOfferFullscreen(), false);
  const late = browser(); late.window.cwOfferFullscreen(); late.install.click();
  late.windowEvents.beforeinstallprompt({preventDefault() {}});
  assert.equal(late.install.hidden, false);
  assert.equal(late.install.textContent, '加入主畫面');
  console.log('PASS: unsupported browsers, policy block, install acceptance/cancellation/failure, fullscreen success/failure, delayed rejection, standalone, late install availability.');
})().catch(error => { console.error(error); process.exitCode = 1; });
