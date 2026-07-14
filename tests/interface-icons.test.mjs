import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const files={
  buildings:'public/assets/ui/buildings/marino-building-icons.svg',
  tasks:'public/assets/ui/tasks/marino-task-icons.svg',
  casino:'public/assets/ui/casino/marino-casino-icons.svg'
};
const sprites=Object.fromEntries(Object.entries(files).map(([key,file])=>[key,fs.readFileSync(file,'utf8')]));
const phase2b=fs.readFileSync('public/js/phase-2b.js','utf8');
const css=fs.readFileSync('public/styles/phase-2b.css','utf8');
const html=fs.readFileSync('public/index.html','utf8');
const manifest=JSON.parse(fs.readFileSync('public/assets/asset-manifest.json','utf8'));

const expected={
  buildings:['building-slot-hall','building-roulette-table','building-blackjack-lounge','building-vip-hall','building-casino-bar','building-security-center','building-hotel','building-marina','building-private-vault','building-penthouse'],
  tasks:['task-daily','task-weekly','task-progress','task-social','task-tap','task-energy','task-vault-collect','task-building-upgrade','task-league','task-login-streak','task-complete','task-locked'],
  casino:['casino-slot','casino-roulette','casino-blackjack','casino-dice','casino-card','casino-jackpot','casino-free-spin','casino-free-bet','casino-chip','casino-vip','casino-win','casino-loss']
};

function symbolIds(source){return [...source.matchAll(/<symbol\s+id="([^"]+)"/g)].map(match=>match[1])}
function assertWellFormed(source){
  const stack=[];const voidTags=new Set(['path','circle','rect','ellipse','line','polyline','polygon']);
  for(const match of source.matchAll(/<(\/)?([a-z][\w:-]*)(?:\s[^<>]*?)?(\/?)>/gi)){
    const closing=Boolean(match[1]),name=match[2],self=Boolean(match[3])||voidTags.has(name);
    if(closing){assert.equal(stack.pop(),name,`unexpected closing ${name}`)}else if(!self)stack.push(name);
  }
  assert.deepEqual(stack,[]);
}

test('all three original sprite files are structurally valid SVG',()=>{for(const source of Object.values(sprites)){assert.match(source,/^<svg[^>]*xmlns="http:\/\/www\.w3\.org\/2000\/svg"/);assert.match(source,/<\/svg>\s*$/);assertWellFormed(source)}});
test('every expected symbol ID exists exactly once',()=>{for(const [group,ids] of Object.entries(expected)){const actual=symbolIds(sprites[group]);assert.deepEqual(actual,ids);assert.equal(new Set(actual).size,actual.length)}const all=Object.values(sprites).flatMap(symbolIds);assert.equal(new Set(all).size,all.length)});
test('symbols share a 24px viewBox and scalable currentColor styling',()=>{for(const source of Object.values(sprites)){assert.doesNotMatch(source,/<symbol(?![^>]*viewBox="0 0 24 24")/);assert.match(source,/stroke:currentColor/);assert.doesNotMatch(source,/#[0-9a-f]{3,8}/i)}});
test('consumer CSS constrains 24px, 32px and 64px renders without overflow',()=>{assert.match(css,/\.marino-sprite-icon\.icon-24\{--marino-icon-size:24px\}/);assert.match(css,/\.marino-sprite-icon\.icon-32\{--marino-icon-size:32px\}/);assert.match(css,/\.marino-sprite-icon\.icon-64\{--marino-icon-size:64px\}/);assert.match(css,/max-width:64px;max-height:64px;aspect-ratio:1;overflow:hidden/)});
test('building, task, casino and reward cards use external sprites with inline fallback',()=>{for(const file of Object.values(files))assert.ok(phase2b.includes(file.replace('public/','./')));assert.match(phase2b,/class="sprite-fallback"/);assert.match(phase2b,/renderCasinoIcons/);assert.doesNotMatch(phase2b,/reward\.type==='spin'\?'S'/)});
test('manifest marks generated sprite sizes and project ownership accurately',()=>{for(const [id,file] of [['marino_building_icons',files.buildings],['marino_task_icons',files.tasks],['marino_casino_icons',files.casino]]){const asset=manifest.assets.find(item=>item.id===id);const canonicalBytes=Buffer.byteLength(fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n'));assert.equal(asset.available,true);assert.equal(asset.license,'Project-owned original');assert.equal(asset.sizeBytes,canonicalBytes)}});
test('Auth RPC economy and static DOM contracts remain unchanged',()=>{assert.match(html,/function authenticateTelegram\(/);assert.match(html,/db\.rpc\('marino_secure_rpc'/);assert.match(html,/rpc\('tap_coin', \{ p_taps: 1 \}\)/);assert.match(html,/function processState\(d\)/);const markup=html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi,'');const ids=[...markup.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);assert.equal(new Set(ids).size,ids.length)});
