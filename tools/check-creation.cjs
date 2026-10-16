const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/lucas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try {
  const page=await browser.newPage({viewport:{width:1200,height:1000}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://localhost:8080/characters.html');
  await page.waitForFunction(()=>document.getElementById('sheet').textContent.includes('PV 12'));
  await page.locator('#class').selectOption('wizard');
  await page.locator('#race').selectOption('elf');
  await page.waitForFunction(()=>document.getElementById('sheet').textContent.includes('CD 13'));
  await page.locator('#class').selectOption('cleric');
  await page.waitForFunction(()=>document.querySelectorAll('#proficiency-replacements select').length===1);
  await page.waitForFunction(()=>document.getElementById('stat-hp').textContent!=='-');
  await page.locator('#class').selectOption('rogue');
  await page.waitForFunction(()=>document.querySelectorAll('#expertise-choices select').length===2);
  await page.locator('#skill-choices select').first().selectOption('athletics');
  await page.locator('#expertise-choices select').first().selectOption('athletics');
  await page.waitForFunction(()=>document.getElementById('sheet').textContent.includes('Especialização: Athletics'));
  await page.locator('#race').selectOption('human');
  await page.locator('#class').selectOption('barbarian');
  await page.waitForFunction(()=>document.getElementById('stat-hp').textContent==='14' && document.getElementById('stat-ac').textContent==='14');
  await page.locator('#class').selectOption('monk');
  await page.waitForFunction(()=>document.getElementById('stat-hp').textContent==='10' && document.getElementById('stat-ac').textContent==='15');
  await page.locator('#password').fill('admin');
  await page.locator('#list').click();
  await page.waitForFunction(()=>document.getElementById('characters').children.length>=2);
  await page.screenshot({path:'runtime/character-creation.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Creation form overflows mobile viewport');
  if(errors.length)throw Error(errors.join('\n'));
  console.log('Browser: form, class/race recalculation and account character list verified.');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
