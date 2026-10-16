const { chromium } = require('C:/Users/lucas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
let activeBrowser;
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--enable-unsafe-swiftshader'] });
  activeBrowser=browser;
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('websocket', ws => { console.log('WS', ws.url()); ws.on('close', () => console.log('WS_CLOSED', ws.url())); ws.on('socketerror', e => console.log('WS_ERROR', String(e))); });
  page.on('console', m => {if(!m.text().includes('monitor run deps') && !m.text().includes('Downloading data')) console.log('CONSOLE',m.type(),m.text());});
  page.on('pageerror',e=>console.log('PAGEERROR',e.message));
  await page.goto('http://localhost:8080/otclient.html',{waitUntil:'domcontentloaded',timeout:60000});
  await page.locator('#start').click({ timeout: 60000 });
  await page.waitForTimeout(15000);
  await page.screenshot({path:'runtime/login-before.png'});
  const click = async (x,y) => { await page.mouse.move(x,y); await page.waitForTimeout(700); await page.mouse.down(); await page.waitForTimeout(200); await page.mouse.up(); };
  await click(600, 378);
  await page.keyboard.type('admin',{delay:150});
  await click(600, 400);
  await page.keyboard.type('admin',{delay:150});
  await click(765, 520);
  await page.waitForTimeout(3500);
  await click(720, 478); // dismiss server MOTD when present
  await page.waitForTimeout(1800);
  await page.screenshot({ path: 'runtime/login-result.png' });
  console.log('TITLE', await page.title());
  if(process.env.INTERACTIVE_CHECK) {
    const readline=require('node:readline');
    for await(const line of readline.createInterface({input:process.stdin})) {
      try { await eval(`(async()=>{${line}})()`); await page.waitForTimeout(1500); await page.screenshot({path:'runtime/login-result.png'}); console.log('DONE'); } catch(e) { console.log(e.message); }
    }
  }
  await browser.close();
})().catch(e => { console.error(e); process.exitCode=1; }).finally(()=>activeBrowser?.close());
