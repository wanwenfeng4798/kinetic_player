import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createServer} from 'node:http';
import {readFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec = promisify(execFile);
const bundle = await readFile(new URL('../../assets/web/kinetic_artplayer.js',import.meta.url));
const movie = await readFile(new URL('../../example/integration_test/fixtures/orientation.mp4',import.meta.url));
const page = `<!doctype html><html><head><style>pre{display:none}</style></head><body style="margin:0;background:#000"><div id="player" style="width:720px;height:240px"></div><pre id="result">PENDING</pre><script src="/player.js"></script><script>
(async()=>{
 let bridge;
 try {
  const container=document.getElementById('player');
  bridge=window.KineticArtplayer.createBridge();
  await bridge.attach({container,url:location.origin+'/movie.mp4',autoPlay:false,ui:{locale:'en',showLockButton:true},...(location.search.includes('plugins')?{artPlugins:{danmuku:true,documentPip:true,hlsControl:true,dashControl:true,multipleSubtitles:true}}:{}),onEvent(){}});
  const root=container.querySelector('.art-video-player');root.classList.add('art-control-show');
  if(location.search.includes('plugins')){for(let i=0;i<30&&!container.querySelector('.apd-emitter');i++)await new Promise(r=>setTimeout(r,50));if(!container.querySelector('.apd-emitter')||!container.querySelector('.art-control-document-pip'))throw Error('Demo plugins did not install');}
  const rows=[];
  for(const width of [240,280,360,720,1280]){
   container.style.width=width+'px';await new Promise(r=>setTimeout(r,80));
   const outer=container.getBoundingClientRect();
   for(const selector of ['.art-control-playAndPause','.art-control-progress','.art-control-kinetic-rate','.art-control-setting','.art-control-volume','.art-control-fullscreen']){
    const el=container.querySelector(selector);if(!el)throw Error('Missing '+selector);
    const box=el.getBoundingClientRect();
    if(box.width<=0||box.left<outer.left-1||box.right>outer.right+1||box.bottom>outer.bottom+1)throw Error(selector+' clipped at '+width+': '+JSON.stringify({x:box.x,y:box.y,width:box.width,height:box.height,outer:outer.width,right:[...container.querySelector('.art-controls-right').children].map(x=>({name:x.className,display:getComputedStyle(x).display,width:x.getBoundingClientRect().width})),grid:getComputedStyle(container.querySelector('.art-controls')).gridTemplateColumns}));
   }
   const track=container.querySelector('.art-control-progress-inner').getBoundingClientRect();
   if(track.width<24||track.height<2||track.height>6)throw Error('Progress track missing at '+width+': '+JSON.stringify({width:track.width,height:track.height}));
   container.querySelector('.art-control-setting').click();await new Promise(r=>setTimeout(r,30));
   const panel=container.querySelector('.art-settings').getBoundingClientRect();
   if(panel.width<=0||panel.left<outer.left-1||panel.right>outer.right+1||panel.top<outer.top-1||panel.bottom>outer.bottom+1)throw Error('Settings clipped at '+width+': '+JSON.stringify({x:panel.x,y:panel.y,width:panel.width,height:panel.height}));
   container.querySelector('.art-control-setting').click();
   const emitter=container.querySelector('.apd-emitter');if(emitter){const box=emitter.getBoundingClientRect();if(box.left<outer.left-1||box.right>outer.right+1||box.bottom>outer.bottom+1)throw Error('Danmuku row clipped at '+width+': '+JSON.stringify({x:box.x,y:box.y,width:box.width,height:box.height,parent:emitter.parentElement.className,parentWidth:emitter.parentElement.getBoundingClientRect().width,controls:container.querySelector('.art-controls').getBoundingClientRect().height}));}
   rows.push(width);
  }
  const video=container.querySelector('video');
  for(let i=0;i<30&&!Number.isFinite(video.duration);i++)await new Promise(r=>setTimeout(r,50));
  if(!Number.isFinite(video.duration))throw Error('Local media metadata missing');
  const seek=container.querySelector('.art-progress'),seekBox=seek.getBoundingClientRect();
  const clickSeek=fraction=>seek.dispatchEvent(new MouseEvent('click',{bubbles:true,clientX:seekBox.left+seekBox.width*fraction,clientY:seekBox.top+seekBox.height/2}));
  clickSeek(.5);await new Promise(r=>setTimeout(r,100));
  if(Math.abs(video.currentTime-video.duration*.5)>1)throw Error('Progress click did not seek native video');
  await bridge.handleMethod('setRate',{rate:1.25});await new Promise(r=>setTimeout(r,80));
  if(container.querySelector('.kinetic-rate-label').textContent!=='1.25x')throw Error('Fractional rate label was rounded');
  await bridge.handleMethod('setRate',{rate:1.5});await new Promise(r=>setTimeout(r,80));
  if(container.querySelector('.kinetic-rate-label').textContent!=='1.5x')throw Error('Rate label did not sync');
  const lock=container.querySelector('.kinetic-lock');lock.click();
  if(!container.classList.contains('kinetic-locked')||getComputedStyle(container.querySelector('.art-bottom')).display!=='none')throw Error('Lock failed');
  const lockedTime=video.currentTime;clickSeek(.8);await new Promise(r=>setTimeout(r,50));
  if(Math.abs(video.currentTime-lockedTime)>.2)throw Error('Locked progress changed native video time');
  lock.click();if(container.classList.contains('kinetic-locked'))throw Error('Unlock failed');
  await bridge.handleMethod('artSetUiConfig',{ui:{showVolumeToolbar:false,showLockButton:false,showSettingsButton:false,accentColor:0xff123456}});
  for(const selector of ['.art-control-volume','.art-control-setting','.kinetic-lock'])if(getComputedStyle(container.querySelector(selector)).display!=='none')throw Error('Runtime hide failed: '+selector);
  if(getComputedStyle(root).getPropertyValue('--art-theme').trim()!=='#123456')throw Error('Runtime theme did not sync');
  await bridge.handleMethod('artSetUiConfig',{ui:{showVolumeToolbar:true,showLockButton:true,showSettingsButton:true,accentColor:0xfffb7299}});
  document.getElementById('result').textContent=JSON.stringify({passed:true,widths:rows,rate:true,lock:true});
 }catch(e){document.getElementById('result').textContent=JSON.stringify({passed:false,error:String(e),stack:e.stack});}
 finally{if(bridge&&!location.search.includes('preview'))await bridge.dispose();else document.getElementById('player').style.width='720px';}
})();</script></body></html>`;

test('Chrome: actual Artplayer toolbar fits five widths and supports rate/lock', {timeout:60000}, async()=>{
 const profile=await mkdtemp(join(tmpdir(),'kinetic-chrome-ui-'));
 const server=createServer((req,res)=>{
  if(req.url==='/movie.mp4'){
   const range=req.headers.range?.match(/bytes=(\d+)-(\d*)/);
   if(range){const start=Number(range[1]),end=range[2]?Math.min(Number(range[2]),movie.length-1):movie.length-1;res.writeHead(206,{'Content-Type':'video/mp4','Content-Range':`bytes ${start}-${end}/${movie.length}`,'Accept-Ranges':'bytes','Content-Length':end-start+1});res.end(movie.subarray(start,end+1));}
   else{res.writeHead(200,{'Content-Type':'video/mp4','Content-Length':movie.length});res.end(movie);}return;
  }
  res.setHeader('Content-Type',req.url==='/player.js'?'application/javascript':'text/html');res.end(req.url==='/player.js'?bundle:page);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  const chrome=process.env.CHROME_EXECUTABLE??(process.platform==='darwin'?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':'google-chrome');
  const {stdout,stderr}=await exec(chrome,['--headless','--disable-gpu','--no-first-run','--no-default-browser-check',`--user-data-dir=${profile}`,'--dump-dom','--virtual-time-budget=10000',`http://127.0.0.1:${server.address().port}`],{timeout:45000,maxBuffer:8*1024*1024});
  const result=stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/)?.[1];
  assert.ok(result&&result!=='PENDING',stderr.slice(-1500));
  const report=JSON.parse(result.replaceAll('&quot;','"').replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));
  assert.equal(report.passed,true,JSON.stringify(report));
  assert.deepEqual(report.widths,[240,280,360,720,1280]);
  const pluginsRun=await exec(chrome,['--headless','--disable-gpu','--no-first-run',`--user-data-dir=${profile}`,'--dump-dom','--virtual-time-budget=10000',`http://127.0.0.1:${server.address().port}/?plugins=1`],{timeout:45000,maxBuffer:8*1024*1024});
  const pluginsResult=pluginsRun.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/)?.[1];
  assert.ok(pluginsResult&&pluginsResult!=='PENDING',pluginsRun.stderr.slice(-1500));
  const pluginsReport=JSON.parse(pluginsResult.replaceAll('&quot;','"').replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));
  assert.equal(pluginsReport.passed,true,JSON.stringify(pluginsReport));

  if(process.env.KINETIC_UI_SCREENSHOT) await exec(chrome,['--headless','--disable-gpu','--no-first-run',`--user-data-dir=${profile}`,'--hide-scrollbars','--window-size=720,360',`--screenshot=${process.env.KINETIC_UI_SCREENSHOT}`,'--virtual-time-budget=10000',`http://127.0.0.1:${server.address().port}/?preview=1`],{timeout:45000,maxBuffer:8*1024*1024});
 }finally{await new Promise(r=>server.close(r));await rm(profile,{recursive:true,force:true});}
});
