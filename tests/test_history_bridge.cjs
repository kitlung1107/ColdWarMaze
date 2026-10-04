const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
function launch({ embedded = true, storage = new Map(),rules=false } = {}) {
  const listeners = {}, docEvents = {}, nodes = {}, messages = [], classes = new Set(); let id = 0, redirected, reloads = 0, tick, now = 0, fallbacks = 0;
  const host = { postMessage: (m,o) => messages.push({m,o}) };
  const document = { documentElement: { classList: { add: x=>classes.add(x), toggle: (x,v)=>v?classes.add(x):classes.delete(x) } }, addEventListener:(name,fn)=>docEvents[name]=fn, getElementById:id=>nodes[id]||null, createElement:()=>({append(){}}), head:{append(){}}, body:{append:node=>nodes[node.id]=node} };
  const window = { HISTORY_GAME_CONFIG: {gameId:'g', version:'v',host:'https://museum.test/'}, addEventListener:(name,fn)=>listeners[name]=fn, cwRequestFullscreen:()=>fallbacks++ };
  if(rules)Object.assign(window.HISTORY_GAME_CONFIG,{rulesProtocol:'rules-game/1',mazeVersion:'trusted-version'});
  window.parent = embedded ? host : window;
  const location = {search:embedded?'?hqChannel=c':'?studentId=spoof',replace:u=>redirected=u,reload:()=>reloads++};
  const localStorage = {getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)};
  const context = {window,parent:window.parent,document,location,localStorage,URL,URLSearchParams,crypto:{randomUUID:()=>`event-${++id}`},setInterval:fn=>tick=fn,Date:{now:()=>now},Map,setTimeout:fn=>fn()};
  vm.runInNewContext(fs.readFileSync('web/history-game-bridge.js','utf8'),context);
  const receive = (data, source=host, origin='https://museum.test') => listeners.message({source,origin,data:{protocol:'history-game/1',channel:'c',...data}});
  return {bridge:window.HistoryGame,messages,receive,host,storage,redirect:()=>redirected,reloads:()=>reloads,tick:()=>tick(),domReady:()=>docEvents.DOMContentLoaded(),fullscreen:()=>window.cwRequestFullscreen(),fallbacks:()=>fallbacks,advance:ms=>now+=ms};
}
test('direct URL redirects through registered museum; spoof student URL is ignored',()=>{
 const game=launch({embedded:false}); assert.equal(game.redirect(),'https://museum.test/?game=g'); assert.equal(game.bridge.start(),false);
});

test('Rules runs bind the published maze, flush routes before door answers and exit, and use one monotonic event sequence',()=>{
 const g=launch({rules:true});g.receive({type:'identity',identity:{scope:'preview:synthetic'}});assert.equal(g.bridge.ready(),false);
 g.receive({type:'identity',identity:{scope:'preview:synthetic',rulesProtocol:'rules-game/1',mazeVersion:'trusted-version'}});
 assert.equal(g.bridge.start('maze-91024','wrong'),false);assert.equal(g.bridge.start('maze-91024','trusted-version'),true);
 for(const cell of [23,24])assert.equal(g.bridge.move(cell),true);
 g.bridge.target({kind:'door',cell:25});g.bridge.answer('1',[1]);g.bridge.move(25);g.bridge.end();
 const events=g.messages.filter(x=>x.m.type==='event').map(x=>x.m.event);
 assert.deepEqual(JSON.parse(JSON.stringify(events.map(e=>e.sequence))),[0,1,2,3,4]);
 assert.equal(events[0].mazeVersion,'trusted-version');assert.equal(events[1].path.length,2);assert.equal(events[2].attempt,1);assert.equal(events[2].target.cell,25);assert.equal(events[4].attempts,1);
 const ids=events.map(e=>e.eventId);g.tick();const replay=g.messages.filter(x=>x.m.type==='event').slice(-5).map(x=>x.m.event);assert.deepEqual(replay.map(e=>e.eventId),ids);
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
test('lost host heartbeat locks gameplay; fullscreen delegates to host without native fallback',()=>{
 const g=launch();g.domReady();g.receive({type:'identity',identity:{scope:'one:s1'}});
 g.fullscreen();assert.equal(g.messages.at(-1).m.type,'fullscreen');
 g.receive({type:'fullscreen-unavailable'});assert.equal(g.fallbacks(),0);
 g.advance(15001);assert.equal(g.bridge.ready(),false);assert.equal(g.bridge.start(),false);
});

test('return preserves the round and rejects unrelated viewport messages',()=>{
const g=launch();g.domReady();g.receive({type:'identity',identity:{scope:'preview:synthetic'}});
g.bridge.start();g.bridge.answer('q',[1]);
g.receive({type:'viewport',expanded:true},{},'https://museum.test');assert.equal(g.bridge.expanded(),false);
g.receive({type:'viewport',channel:'wrong',expanded:true});assert.equal(g.bridge.expanded(),false);
g.receive({type:'viewport',expanded:true});assert.equal(g.bridge.expanded(),true);
g.bridge.returnToView();assert.equal(g.messages.at(-1).m.type,'return-to-view');
g.receive({type:'viewport',expanded:false});assert.equal(g.bridge.expanded(),false);
g.bridge.answer('q2',[0]);g.bridge.end();
const events=g.messages.filter(x=>x.m.type==='event').map(x=>x.m.event);
assert.equal(events.length,4);assert.equal(events[2].sessionId,events[0].sessionId);
assert.equal(events[2].sequence,2);assert.equal(events[3].outcome,'completed');assert.equal(g.reloads(),0);
});
