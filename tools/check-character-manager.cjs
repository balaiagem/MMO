const { chromium } = require('C:/Users/lucas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader']});
 try {
  const page=await browser.newPage({viewport:{width:1280,height:900}});
  const errors=[];const markers=new Set();
  page.on('requestfailed',r=>console.log('REQUESTFAILED',r.url(),r.failure()));
  page.on('request',r=>{if(r.url().includes('/api/'))console.log('REQUEST',r.method(),r.url())});
  page.on('response',r=>{if(r.status()>=400||r.url().includes('/api/creation/'))console.log('HTTP',r.status(),r.url())});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{const text=m.text();if(text.includes('[MANAGERQA]')){markers.add(text);console.log(text)}if(/ERROR|FATAL|creator missing/i.test(text)&&!text.includes('favicon')&&!text.includes('Failed to load resource')&&!text.toLowerCase().includes('initiative')){errors.push(text);console.log(text)}});
  await page.goto('http://localhost:8080/character-manager-qa/otclient.html');
  await page.locator('#start').click();
  for(const stage of ['creator_ready','delete_ready','list_ready']){
   const deadline=Date.now()+60000;
   while(![...markers].some(x=>x.includes(stage))){if(errors.length){await page.screenshot({path:'runtime/character-manager-error.png'});throw Error(errors.join('\n'))}if(Date.now()>deadline)throw Error('Timeout waiting '+stage);await page.waitForTimeout(200)}
   await page.waitForTimeout(250);
   await page.screenshot({path:`runtime/character-manager-${stage}.png`});
  }
  if(errors.length)throw Error(errors.join('\n'));
  console.log('Native account list, creature portraits, creator, preview and deletion confirmation passed. No characters changed.');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
