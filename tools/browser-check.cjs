const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/lucas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.on('console', m => {if(!m.text().includes('monitor run deps')) console.log(m.type()+': '+m.text())});
  page.on('pageerror', e => console.log('PAGEERROR: '+e.message));
  page.on('requestfailed', r => console.log('REQUESTFAILED: '+r.url()+' '+r.failure()?.errorText));
  await page.goto('http://localhost:8080/otclient.html');
  await page.locator('#start').click({timeout:60000});
  await page.waitForTimeout(12000);
  await page.mouse.click(765,460,{delay:200});
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'runtime/browser-start.png' });
  console.log('PAGE:', await page.title(), 'ISOLATED:', await page.evaluate(() => crossOriginIsolated));
  if(process.env.INTERACTIVE_CHECK) {
    const readline=require('node:readline');
    for await(const line of readline.createInterface({input:process.stdin})) {
      try { await eval(line); await page.waitForTimeout(1500); await page.screenshot({path:'runtime/browser-start.png'}); console.log('DONE'); } catch(e) { console.log(e.message); }
    }
  }
  await browser.close();
})().catch(e => { console.error(e); process.exitCode=1; });
