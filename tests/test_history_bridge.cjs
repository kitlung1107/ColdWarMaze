const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function launch({ embedded = true, storage = new Map() } = {}) {
  const listeners = {}, docEvents = {}, nodes = {}, messages = [], classes = new Set(); let id = 0, redirected, reloads = 0, tick, now = 0, fallbacks = 0;
  const host = { postMessage: (m,o) => messages.push({m,o}) };
  const document = { documentElement: { classList: { add: x=>classes.add(x), toggle: (x,v)=>v?classes.add(x):classes.delete(x) } }, addEventListener:(name,fn)=>docEvents[name]=fn, getElementById:id=>nodes[id]||null, createElement:()=>({append(){}}), head:{append(){}}, body:{append:node=>nodes[node.id]=node} };
  const window = { HISTORY_GAME_CONFIG: {gameId:'g', version:'v',host:'https://museum.test/'}, addEventListener:(name,fn)=>listeners[name]=fn, cwRequestFullscreen:()=>fallbacks++ };
  window.parent = embedded ? host : window;
  const location = {search:embedded?'?hqChannel=c':'?studentId=spoof',replace:u=>redirected=u,reload:()=>reloads++};
  const localStorage = {getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)};
  const context = {window,parent:window.parent,document,location,localStorage,URL,URLSearchParams,crypto:{randomUUID:()=>`event-${++id}`},setInterval:fn=>tick=fn,Date:{now:()=>now},Map,queueMicrotask:fn=>fn()};
  vm.runInNewContext(fs.readFileSync('web/history-game-bridge.js','utf8'),context);
  const receive = (data, source=host, origin='https://museum.test') => listeners.message({source,origin,data:{protocol:'history-game/1',channel:'c',...data}});
  return {bridge:window.HistoryGame,messages,receive,host,storage,redirect:()=>redirected,reloads:()=>reloads,tick:()=>tick(),domReady:()=>docEvents.DOMContentLoaded(),fullscreen:()=>window.cwRequestFullscreen(),fallbacks:()=>fallbacks,advance:ms=>now+=ms};
}
test('direct URL redirects through registered museum; spoof student URL is ignored',()=>{
 const game=launch({embedded:false}); assert.equal(game.redirect(),'https://museum.test/?game=g'); assert.equal(game.bridge.start(),false);
});
test('only exact parent, origin and channel can unlock; native fullscreen does not replace identity',()=>{
 const game=launch();
 game.receive({type:'identity',identity:{scope:'u:s'}},{},'https://museum.test'); assert.equal(game.bridge.ready(),false);
 game.receive({type:'identity',identity:{scope:'u:s'}},game.host,'https://evil.test'); assert.equal(game.bridge.ready(),false);
 game.receive({type:'identity',channel:'wrong',identity:{scope:'u:s'}}); assert.equal(game.bridge.ready(),false);
 game.receive({type:'identity',identity:{scope:'u:s'}}); assert.equal(game.bridge.ready(),true);
});
test('answer arrays, stable retries, per-submit sequence, and exactly one completion per round',()=>{
 const g=launch();g.receive({type:'identity',identity:{scope:'u:s'}});g.bridge.start();g.bridge.answer('q',[2,0,1]);g.bridge.answer('q',[0,2,1]);g.bridge.end();g.bridge.end();
 const events=g.messages.filter(x=>x.m.type==='event').map(x=>x.m.event);assert.equal(events.length,4);
 assert.deepEqual(JSON.parse(JSON.stringify(events.map(e=>e.sequence))),[0,1,2,3]);assert.equal(events[3].attempts,2);
 assert.deepEqual(JSON.parse(JSON.stringify(events[1].answer)),[2,0,1]);
 g.tick(); const retry=g.messages.filter(x=>x.m.type==='event').map(x=>x.m.event);assert.equal(retry[4].eventId,events[0].eventId);
 for(const e of events)g.receive({type:'accepted',eventId:e.eventId}); const count=g.messages.length;g.tick();assert.equal(g.messages.length,count+1);
 g.bridge.start();g.bridge.end('abandoned');assert.equal(g.messages.at(-1).m.event.outcome,'abandoned');
});
test('anonymous history never imports; a changed account after lock reloads without replaying old work',()=>{
 const storage=new Map([['coldwar-study-v1','old anonymous']]);const g=launch({storage});
 g.receive({type:'identity',identity:{scope:'one:s1'}});assert.equal(g.bridge.progress(),'');g.bridge.progress('one history');g.bridge.start();g.bridge.answer('q',[1]);
 g.receive({type:'locked'});assert.equal(g.bridge.ready(),false);g.receive({type:'identity',identity:{scope:'two:s2'}});assert.equal(g.reloads(),1);assert.equal(g.bridge.ready(),false);
 const other=launch({storage});other.receive({type:'identity',identity:{scope:'two:s2'}});assert.equal(other.bridge.progress(),'');
});
test('lost host heartbeat locks gameplay; fullscreen delegates to host and retains mobile fallback',()=>{
 const g=launch();g.domReady();g.receive({type:'identity',identity:{scope:'one:s1'}});
 g.fullscreen();assert.equal(g.messages.at(-1).m.type,'fullscreen');
 g.receive({type:'fullscreen-unavailable'});assert.equal(g.fallbacks(),1);
 g.advance(15001);assert.equal(g.bridge.ready(),false);assert.equal(g.bridge.start(),false);
});
