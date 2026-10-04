// Trusted release inputs: maps are published by the existing operator, never by a player.
const fs=require('node:fs'),crypto=require('node:crypto'),path=require('node:path');
const W=21,H=13,start=W+1;
const adjacent=p=>[p-W,p+1,p+W,p-1].filter(n=>n>=0&&n<W*H&&Math.abs(n%W-p%W)+Math.abs(Math.floor(n/W)-Math.floor(p/W))===1);
function create(seed){
 let state=seed>>>0;const random=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;return(state>>>0)/4294967296;};
 const shuffle=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const floors=new Set([start]),stack=[start];
 while(stack.length){const p=stack.at(-1),x=p%W,y=Math.floor(p/W);const dirs=[[0,-1],[1,0],[0,1],[-1,0]].filter(([dx,dy])=>x+2*dx>0&&x+2*dx<W-1&&y+2*dy>0&&y+2*dy<H-1&&!floors.has(p+2*(dy*W+dx)));if(!dirs.length){stack.pop();continue;}const [dx,dy]=dirs[Math.floor(random()*dirs.length)],d=dy*W+dx;floors.add(p+d);floors.add(p+2*d);stack.push(p+2*d);}
 function distances(origin){const out=new Map([[origin,0]]),queue=[origin];for(let i=0;i<queue.length;i++)for(const n of adjacent(queue[i]))if(floors.has(n)&&!out.has(n)){out.set(n,out.get(queue[i])+1);queue.push(n);}return out;}
 function route(a,b){const parent=new Map([[a,a]]),queue=[a];for(let i=0;i<queue.length&&!parent.has(b);i++)for(const n of adjacent(queue[i]))if(floors.has(n)&&!parent.has(n)){parent.set(n,queue[i]);queue.push(n);}const out=[b];while(out.at(-1)!==a)out.push(parent.get(out.at(-1)));return out.reverse();}
 const distance=distances(start),rooms=[...floors].filter(p=>p%W%2===1&&Math.floor(p/W)%2===1&&p!==start).sort((a,b)=>distance.get(b)-distance.get(a));
 const finish=rooms[0],chosen=[start,finish],files=[];
 for(let i=0;i<3;i++){const maps=chosen.map(distances);let best=-1,bestScore=-1;for(const p of rooms){if(chosen.includes(p)||distance.get(p)<10)continue;const score=Math.min(...maps.map(m=>m.get(p)))+distance.get(p)*.25;if(score>bestScore){bestScore=score;best=p;}}files.push(best);chosen.push(best);}
 const halls=[],doors=new Set();for(const goal of chosen.slice(1)){const r=route(start,goal);for(const p of r)if((p%W%2===0||Math.floor(p/W)%2===0)&&!halls.includes(p)&&distance.get(p)>2)halls.push(p);if(files.includes(goal))doors.add(r.at(-2));}
 halls.sort((a,b)=>distance.get(a)-distance.get(b));for(let i=0;i<10&&halls.length;i++)doors.add(halls[Math.floor(i/10*halls.length)]);
 const free=shuffle(rooms.filter(p=>!chosen.includes(p)&&distance.get(p)>=4)),chests=free.slice(0,6),towers=free.slice(6,9),shortcuts=[];
 for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){const p=y*W+x,axis=x%2===0?1:W;if(floors.has(p)||x%2===y%2||Math.abs(x-finish%W)+Math.abs(y-Math.floor(finish/W))<5)continue;if(floors.has(p-axis)&&floors.has(p+axis)&&route(p-axis,p+axis).length>=10)shortcuts.push(p);}
 return {id:'maze-'+String(seed),seed,width:W,height:H,start,finish,files,floors:[...floors].sort((a,b)=>a-b),floorCells:Object.fromEntries([...floors].map(n=>[String(n),true])),doors:[...doors].sort((a,b)=>a-b),chests,towers,shortcuts:shuffle(shortcuts).slice(0,3)};
}
const layouts=Array.from({length:128},(_,i)=>create(91024+i*7919));
const gameId='cold-war-maze',questionVersion=JSON.parse(fs.readFileSync(path.join(__dirname,'../web/history-game-config.js'),'utf8').split(' = ')[1].replace(/;\s*$/,'' )).version;
const mazeVersion=crypto.createHash('sha256').update(JSON.stringify({protocol:'rules-game/1',gameId,questionVersion,layouts})).digest('hex').slice(0,32);
const result={protocol:'rules-game/1',gameId,questionVersion,mazeVersion,layouts};
const output=path.join(__dirname,'../data/trusted-mazes.json'),text=JSON.stringify(result)+'\n';
if(process.argv.includes('--check')){if(fs.readFileSync(output,'utf8').replaceAll('\r\n','\n')!==text)throw Error('Trusted maze release inputs changed');}else fs.writeFileSync(output,text);
console.log(JSON.stringify({mazeVersion,maps:layouts.length,bytes:Buffer.byteLength(text)}));
