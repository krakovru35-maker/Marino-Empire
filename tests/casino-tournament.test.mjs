import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('../public/js/casino/casino-tournament.js',import.meta.url),'utf8');
const module={exports:{}};
vm.runInNewContext(source,{module,exports:module.exports,globalThis:{},Set,Object,Date,Math,Array});
const tournament=module.exports;

test('local preview leaderboard 20 güvenli mock oyuncu içerir',()=>{
  assert.equal(tournament.MOCK_PLAYERS.length,20);
  const board=tournament.leaderboard(tournament.createTournamentState());
  assert.equal(board.length,21);
  assert.equal([...board].sort((a,b)=>b.score-a.score).map(item=>item.id).join(','),board.map(item=>item.id).join(','));
});

test('turnuva puanı bahis miktarı ve kazançtan bağımsızdır',()=>{
  const a=tournament.createTournamentState(),b=tournament.createTournamentState();
  tournament.applyTournamentEvent(a,'mission_claim',{bet:5,win:0});
  tournament.applyTournamentEvent(b,'mission_claim',{bet:50000,win:999999});
  assert.equal(a.score,b.score);
  assert.equal(a.score,12);
});

test('yalnız görev zinciri ve üçlü ziyaret skor üretir',()=>{
  const state=tournament.createTournamentState();
  tournament.applyTournamentEvent(state,'slot_spin',{bet:100});
  assert.equal(state.score,0);
  tournament.applyTournamentEvent(state,'chain_complete');
  tournament.applyTournamentEvent(state,'triple_visit');
  assert.equal(state.score,60);
});

test('oyuncu skoru arttıkça sırası yükselir',()=>{
  const state=tournament.createTournamentState();
  const before=tournament.leaderboard(state).find(item=>item.id==='local-player').rank;
  for(let i=0;i<10;i++)tournament.applyTournamentEvent(state,'chain_complete');
  const after=tournament.leaderboard(state).find(item=>item.id==='local-player').rank;
  assert.ok(after<before);
});

test('gerçek mod kalıcı leaderboard üretmez ve preview kontrolü zorunludur',()=>{
  assert.match(source,/if\(!event\.detail\?\.preview\|\|!preview\(\)\)return/);
  assert.match(source,/Salt okunur önizleme/);
  assert.doesNotMatch(source,/marino_secure_rpc|tap_coin|fetch\s*\(/);
});

test('sorumlu oyun ve önizleme etiketleri görünürdür',()=>{
  assert.match(source,/Bahis miktarı, kazanç veya kayıp skoru etkilemez/);
  assert.match(source,/NAKİT DEĞERİ YOKTUR/);
  assert.match(source,/20 dakikada mola önerilir/);
});

test('on bir casino rozeti özgün SVG symbol taşır',()=>{
  const svg=fs.readFileSync(new URL('../public/assets/ui/casino/marino-casino-badges.svg',import.meta.url),'utf8');
  assert.equal([...svg.matchAll(/<symbol\s+id="badge-[^"]+"/g)].length,11);
  assert.equal(new Set([...svg.matchAll(/id="(badge-[^"]+)"/g)].map(match=>match[1])).size,11);
  assert.match(svg,/currentColor/);
});
