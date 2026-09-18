// Usage: node test_web_audio.cjs <web-directory> <playwright-module-path>
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const {chromium} = require(process.argv[3] || 'playwright');
const folder = path.resolve(process.argv[2]);
(async () => {
  const server = http.createServer((req,res) => {
    const target = path.join(folder, decodeURIComponent(req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0]));
    if (!target.startsWith(folder + path.sep)) {res.writeHead(403).end(); return;}
    const mime = {'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm'};
    fs.readFile(target,(err,body) => {res.writeHead(err?404:200,{'Content-Type':mime[path.extname(target)] || 'application/octet-stream'});res.end(err?'missing':body);});
  }).listen(0,'127.0.0.1');
  await new Promise(r=>server.on('listening',r));
  let browser;
  try {
    browser = await chromium.launch({channel:'msedge',headless:true,args:['--autoplay-policy=no-user-gesture-required']});
    const page = await browser.newPage({viewport:{width:1280,height:720}});
    const logs=[],errors=[];
    page.on('console', msg=>{logs.push(msg.text()); if(msg.type()==='error') errors.push(msg.text()+' '+msg.location().url);});
    page.on('pageerror',err=>errors.push(err.message));
    await page.addInitScript(() => {
      window.audioSamples=[];
      const original = AudioNode.prototype.connect;
      const analysers = new Map();
      const observed = new WeakSet();
      AudioNode.prototype.connect = function(target,...args) {
        if(target instanceof AudioDestinationNode && !observed.has(this)) {
          observed.add(this);
          if(analysers.has(this.context)) {
            original.call(this,analysers.get(this.context));
            return original.call(this,target,...args);
          }
          const analyser=this.context.createAnalyser(); analyser.fftSize=2048;
          analysers.set(this.context,analyser);
          original.call(this,analyser);
          const data=new Float32Array(analyser.fftSize);
          setInterval(()=>{analyser.getFloatTimeDomainData(data);window.audioSamples.push({t:performance.now()/1000,rms:Math.sqrt(data.reduce((s,x)=>s+x*x,0)/data.length),state:this.context.state});},100);
        }
        return original.call(this,target,...args);
      };
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.waitForFunction(()=>window.audioSamples?.some(x=>x.rms>0.0001),{},{timeout:60000});
    await page.waitForFunction(()=>window.audioSamples.length>300,{},{timeout:60000});
    const samples=await page.evaluate(()=>window.audioSamples);
    const tail=samples.slice(-30);
    const report={errors,stress:logs.filter(x=>x.includes('AUDIO_STRESS')),tailMin:Math.min(...tail.map(x=>x.rms)),tailMax:Math.max(...tail.map(x=>x.rms)),silentTail:tail.filter(x=>x.rms<0.00001).length};
    fs.writeFileSync(path.join(folder,'audio-report.json'),JSON.stringify({report,samples},null,2));
    console.log(JSON.stringify(report));
    assert(logs.some(x=>x.includes('AUDIO_STRESS_DONE count=300')), 'All 300 switch presses completed');
    assert.equal(errors.length,0,'No browser audio errors');
    assert(tail.some(x=>x.rms>0.0001),'Music remains audible after switching stops');
  } finally {await browser?.close();server.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
