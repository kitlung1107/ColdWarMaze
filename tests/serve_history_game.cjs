const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const root=path.resolve('build/web');
const config=JSON.parse(fs.readFileSync('web/history-game-config.js','utf8').split(' = ')[1].replace(/;\s*$/,''));
config.host='http://127.0.0.1:5177/';
const controls=`<div style="position:fixed;top:0;right:0;z-index:800;background:white;color:black;padding:8px;font:14px sans-serif"><b>本機協定測試</b><button onclick="HistoryGame.start();HistoryGame.answer('1',[0]);HistoryGame.answer('1',[0]);HistoryGame.answer('1',[1]);HistoryGame.end();HistoryGame.end()">測試一局：錯錯對＋重複結算</button><button onclick="HistoryGame.start();HistoryGame.answer('1',[1]);HistoryGame.end()">測試另一局：全對</button><button onclick="HistoryGame.start();HistoryGame.answer('1',[0])">測試未完成局</button></div>`;
const scenario=`<script>let qaTicks=0;setInterval(()=>{if(!HistoryGame.ready())return;if(++qaTicks<3)return;const scope=HistoryGame.identity().scope;if(sessionStorage.getItem('qa-runs:'+scope))return;sessionStorage.setItem('qa-runs:'+scope,'1');HistoryGame.start();HistoryGame.answer('1',[0]);HistoryGame.answer('1',[0]);HistoryGame.answer('1',[1]);HistoryGame.end();HistoryGame.end();HistoryGame.start();HistoryGame.answer('1',[1]);HistoryGame.end();HistoryGame.start();HistoryGame.answer('1',[0]);const label=document.createElement('p');label.textContent='本機測試：已送出兩個完成局＋一個未完成局';label.style='position:fixed;top:45px;right:0;z-index:800;background:white;color:black';document.body.append(label);},1000);</script>`;
const offlineScenario=`<script>addEventListener('message',e=>{if(e.source!==parent||e.origin!=='http://127.0.0.1:5177'||e.data?.type!=='qa-offline-round')return;HistoryGame.start();HistoryGame.answer('1',[0]);HistoryGame.answer('1',[1]);HistoryGame.end();const note=document.createElement('p');note.textContent='本機斷線測試：2 次作答＋結算已送出';note.style='position:fixed;top:75px;right:0;z-index:800;background:white;color:black';document.body.append(note);});</script>`;
http.createServer((req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/history-game-config.js'){res.writeHead(200,{'Content-Type':'application/javascript'});res.end('window.HISTORY_GAME_CONFIG='+JSON.stringify(config)+';');return;}
 const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
 if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
 fs.readFile(file,(err,data)=>{
  if(err){res.writeHead(404).end();return;}
  const ext=path.extname(file);res.writeHead(200,{'Content-Type':({'.html':'text/html; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm'})[ext]||'application/octet-stream'});
  res.end(ext==='.html'?data.toString().replace('</body>',controls+scenario+offlineScenario+'</body>'):data);
 });
}).listen(8186,'127.0.0.1',()=>console.log('Local Godot integration QA at http://127.0.0.1:8186'));
