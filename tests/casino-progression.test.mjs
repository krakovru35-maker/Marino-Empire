import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const read=file=>fs.readFileSync(new URL(`../${file}`,import.meta.url),'utf8');
function load(file){const module={exports:{}};vm.runInNewContext(read(file),{module,exports:module.exports,globalThis:{},Set,Map,Object,Date,Math,Number,Array});return module.exports;}
const missions=load('public/js/casino/casino-missions.js');
const mastery=load('public/js/casino/casino-mastery.js');

test('slot, roulette ve blackjack görev metrikleri ilerler',()=>{
  const state=missions.createProgressState();
  missions.applyProgressEvent(state,'slot_spin');
  missions.applyProgressEvent(state,'roulette_bet',{type:'split'});
  missions.applyProgressEvent(state,'blackjack_double');
  assert.equal(state.metrics.slot_spin,1);
  assert.equal(state.metrics.roulette_split,1);
  assert.equal(state.metrics.blackjack_double,1);
});

test('görev zinciri adımları atlanamaz',()=>{
  const state=missions.createProgressState();
  missions.applyProgressEvent(state,'slot_payline_win');
  assert.equal(state.chainStage.slot_chain,0);
  missions.applyProgressEvent(state,'slot_spin');
  for(let i=0;i<4;i++)missions.applyProgressEvent(state,'slot_spin');
  assert.equal(state.chainStage.slot_chain,2);
  missions.applyProgressEvent(state,'slot_payline_win');
  assert.equal(state.chainStage.slot_chain,3);
});

test('eksik ve ikinci kez görev ödülü alınamaz',()=>{
  const state=missions.createProgressState();
  assert.equal(missions.claimMissionState(state,'roulette_split',true).ok,false);
  missions.applyProgressEvent(state,'roulette_bet',{type:'split'});
  assert.equal(missions.claimMissionState(state,'roulette_split',true).ok,true);
  assert.equal(missions.claimMissionState(state,'roulette_split',true).ok,false);
});

test('gerçek mod yetkisi olmadan istemci görev ödülü üretemez',()=>{
  const state=missions.createProgressState();
  missions.applyProgressEvent(state,'roulette_bet',{type:'split'});
  assert.equal(missions.claimMissionState(state,'roulette_split',false).points,0);
  const source=read('public/js/casino/casino-missions.js');
  assert.match(source,/claimMissionState\(state,id,preview\(\)\)/);
  assert.match(source,/grantDemoRewardPoints/);
});

test('ustalık puanı bahis miktarından bağımsızdır',()=>{
  const a=mastery.createMasteryState(),b=mastery.createMasteryState();
  mastery.applyMasteryEvent(a,'roulette_bet',{amount:5});
  mastery.applyMasteryEvent(b,'roulette_bet',{amount:50000});
  assert.equal(a.points.roulette,b.points.roulette);
});

test('ustalık seviyeleri ve kozmetik rozetler açılır',()=>{
  assert.equal(mastery.levelFor(0).name,'Acemi');
  assert.equal(mastery.levelFor(140).name,'Marino Ustası');
  const state=mastery.createMasteryState();
  mastery.applyMasteryEvent(state,'slot_spin');
  assert.equal(state.badges.has('first-spin'),true);
});

test('kataloglar UI otoritesi olmadığını açıkça belirtir',()=>{
  for(const file of ['public/data/casino/casino-missions.json','public/data/casino/casino-badges.json']){
    const data=JSON.parse(read(file));
    assert.match(JSON.stringify(data),/authority/i);
    assert.match(JSON.stringify(data),/demo|cosmetic|catalog/i);
  }
});

test('Free Spin ve Free Bet hibeleri localhost preview korumasındadır',()=>{
  const source=read('public/js/phase-2b.js');
  assert.match(source,/grantDemoRewardPoints\(amount\).*?!preview\(\)/s);
  assert.match(source,/grantDemoEntitlement\(type,amount=1\).*?!preview\(\)/s);
});

test('responsive görev sheeti ve reduced motion fallback vardır',()=>{
  const css=read('public/styles/casino/casino-progression.css');
  assert.match(css,/@media\(max-width:359px\)/);
  assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
  assert.match(css,/max-height:min\(88dvh,820px\)/);
});

test('korunan RPC ve ekonomi imzaları değişmeden mevcuttur',()=>{
  const html=read('public/index.html');
  assert.match(html,/authenticateTelegram/);
  assert.match(html,/marino_secure_rpc/);
  assert.match(html,/tap_coin/);
  assert.match(html,/p_taps:\s*batchSize/);
});
