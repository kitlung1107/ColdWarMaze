/* History Quest game protocol v1. No Firebase credentials or student IDs in URLs. */
(function () {
  'use strict';
  const config = window.HISTORY_GAME_CONFIG;
  const host = new URL(config.host);
  const channel = new URLSearchParams(location.search).get('hqChannel');
  const embedded = window.parent !== window && channel;
  let identity = null, ownerScope = null, lastHost = 0, session = null, attempts = 0;
  const pending = new Map();
  let expanded = false;
  const bridge = window.HistoryGame = {
    ready: () => !!identity && Date.now() - lastHost < 15000,
    identity: () => identity,
    expanded: () => expanded,
    returnToView() { post({ type: 'return-to-view' }); },
    start() {
      if (!bridge.ready()) return false;
      if (session) bridge.end('abandoned');
      session = crypto.randomUUID();
      attempts = 0;
      sendEvent({ type: 'start', sessionId: session, sequence: 0 });
      return true;
    },
    answer(questionId, answer) {
      if (!bridge.ready() || !session) return false;
      attempts++;
      sendEvent({ type: 'answer', sessionId: session, questionId: String(questionId), answer, sequence: attempts });
      return true;
    },
    end(outcome = 'completed') {
      if (!session) return;
      sendEvent({ type: 'end', sessionId: session, outcome, attempts, sequence: attempts + 1 });
      session = null;
    },
    progress(value) {
      if (!identity) return value === undefined ? '' : false;
      const key = 'hq-study-v1:' + config.gameId + ':' + identity.scope;
      try {
        if (value === undefined) return localStorage.getItem(key) || '';
        localStorage.setItem(key, value); return true;
      } catch (_) { return value === undefined ? '' : false; }
    }
  };
  function post(data) {
    if (embedded) parent.postMessage({ protocol: 'history-game/1', channel, gameId: config.gameId, version: config.version, ...data }, host.origin);
  }
  function sendEvent(event) {
    const id = crypto.randomUUID();
    pending.set(id, { ...event, eventId: id });
    post({ type: 'event', event: pending.get(id) });
  }
  window.addEventListener('message', event => {
    const d = event.data;
    if (event.source !== parent || event.origin !== host.origin || !d || d.protocol !== 'history-game/1' || d.channel !== channel) return;
    if (d.type === 'identity') {
      if (ownerScope && ownerScope !== d.identity.scope) { identity = null; pending.clear(); location.reload(); return; }
      identity = d.identity; ownerScope = identity.scope; lastHost = Date.now();
    }
    if (d.type === 'locked') { identity = null; lastHost = 0; }
    if (d.type === 'accepted') pending.delete(d.eventId);
    if (d.type === 'viewport') expanded = d.expanded === true;
  });
  function tick() {
    post({ type: 'hello' });
    if (bridge.ready()) for (const event of pending.values()) post({ type: 'event', event });
    document.documentElement.classList.toggle('hq-locked', !bridge.ready());
    const gate = document.getElementById('hq-login-gate');
    if (gate) gate.hidden = bridge.ready();
  }
  const entry = new URL(host); entry.searchParams.set('game', config.gameId);
  // Direct URLs always return through the account gate. The game path is registry-controlled.
  if (!embedded) location.replace(entry.href);
  document.addEventListener('DOMContentLoaded', () => {
    const style = document.createElement('style');
    style.textContent = '.hq-locked #canvas{visibility:hidden}#hq-login-gate{position:fixed;inset:0;z-index:9999;background:#0b131d;color:#e8e4d5;display:grid;place-content:center;padding:24px;font:20px/1.7 sans-serif}#hq-login-gate[hidden]{display:none}#hq-login-gate a{color:#77c7b3}';
    document.head.append(style);
    const gate = document.createElement('section'); gate.id = 'hq-login-gate';
    const message = document.createElement('p'); message.textContent = '正在核對探索館登入…如連線中斷，請重新連線。';
    const link = document.createElement('a'); link.href = entry.href; link.target = '_top'; link.textContent = '前往探索館登入並返回遊戲';
    gate.append(message, link); document.body.append(gate); tick();
    // The host owns viewport expansion, including Safari and standalone.
    // Do not fall back to native fullscreen or require installation in the iframe.
    // A microtask can run between DOMContentLoaded listeners. Wait for the
    // template listener to finish defining its helpers before overriding them.
    setTimeout(() => {
      window.cwRequestFullscreen = () => {
        const prompt = document.getElementById('cw-fullscreen-help');
        if (prompt) prompt.hidden = true;
        window.cwFullscreenPromptOpen = false;
        post({ type: 'fullscreen' });
      };
      window.cwOfferFullscreen = () => { window.cwRequestFullscreen(); return false; };
    }, 0);
  });
  document.documentElement.classList.add('hq-locked');
  window.addEventListener('beforeunload', event => {
    if (pending.size) { event.preventDefault(); event.returnValue = ''; }
  });
  setInterval(tick, 2000);
})();
