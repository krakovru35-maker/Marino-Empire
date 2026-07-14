import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

function load(){const context={globalThis:{},module:{exports:{}},console};context.globalThis=context;vm.runInNewContext(fs.readFileSync('public/js/casino/rng-adapter.js','utf8'),context);context.MarinoRng=context.module.exports;context.module={exports:{}};vm.runInNewContext(fs.readFileSync('public/js/casino/roulette.js','utf8'),context);return context.module.exports;}
const roulette=load();
const js=fs.readFileSync('public/js/casino/roulette.js','utf8');
const css=fs.readFileSync('public/styles/casino/roulette.css','utf8');
const byKey=key=>roulette.INSIDE_BETS.find(bet=>bet.key===key);

test('canonical inside bets cover required straight split corner street and six line points',()=>{
  assert.deepEqual(Array.from(byKey('straight:9').numbers),[9]);
  assert.deepEqual(Array.from(byKey('split:9-12').numbers),[9,12]);
  assert.deepEqual(Array.from(byKey('split:8-9').numbers),[8,9]);
  assert.deepEqual(Array.from(byKey('corner:8-9-11-12').numbers),[8,9,11,12]);
  assert.deepEqual(Array.from(byKey('street:10-11-12').numbers),[10,11,12]);
  assert.deepEqual(Array.from(byKey('sixline:7-8-9-10-11-12').numbers),[7,8,9,10,11,12]);
});

test('canonical keys sort numbers and repeated placement merges its stake',()=>{
  assert.equal(roulette.canonicalBetKey('corner',[12,8,11,9]),'corner:8-9-11-12');
  const bets=[];const descriptor={type:'split',numbers:[12,9],key:'split:9-12'};
  roulette.mergeBet(bets,descriptor,10,false);roulette.mergeBet(bets,descriptor,25,false);
  assert.equal(bets.length,1);assert.equal(bets[0].amount,35);assert.equal(bets[0].count,2);assert.deepEqual(Array.from(bets[0].numbers),[9,12]);
});

test('inside payout ratios remain standard demo presentation ratios',()=>{
  assert.equal(roulette.PAYOUT.straight,35);assert.equal(roulette.PAYOUT.split,17);assert.equal(roulette.PAYOUT.street,11);assert.equal(roulette.PAYOUT.corner,8);assert.equal(roulette.PAYOUT.sixline,5);
});

test('ball target and pocket center share one clockwise coordinate system',()=>{
  for(const number of [0,32,23,9,12,26]){const index=roulette.WHEEL.indexOf(number),result={number,index,wheelTurns:6,ballTurns:8,pocketOffset:0},rotation=roulette.nextRotations({wheelRotation:137,ballRotation:-419},result);assert.ok(Math.abs(roulette.normalizeDegrees(rotation.ballRotation)-roulette.normalizeDegrees(rotation.pocketCenter))<1e-9);assert.equal(roulette.getPocketScreenAngle(index,rotation.wheelRotation),roulette.normalizeDegrees(rotation.pocketCenter));}
});

test('physical pocket variation remains within twenty percent of a pocket',()=>{
  const result={number:9,index:roulette.WHEEL.indexOf(9),wheelTurns:5,ballTurns:7,pocketOffset:999},rotation=roulette.nextRotations({wheelRotation:0,ballRotation:0},result);const difference=Math.abs((((roulette.normalizeDegrees(rotation.ballRotation)-roulette.normalizeDegrees(rotation.pocketCenter)+540)%360)-180));assert.ok(difference<=roulette.POCKET_ANGLE*.2+1e-9);
});

test('real ball dot, detached marker layer and precision hit zones are present',()=>{
  assert.match(js,/class="roulette-ball-dot"/);assert.match(js,/class="roulette-bet-layer"/);assert.match(js,/class="roulette-marker-layer"/);assert.match(js,/orientationchange/);assert.match(js,/viewportChanged/);assert.match(js,/getBoundingClientRect/);assert.match(css,/\.roulette-ball-dot\{[^}]*translate:-50% 0/);assert.match(css,/\.roulette-hit-zone\{[^}]*min-width:14px/);assert.match(css,/\.roulette-marker-layer\{position:absolute/);assert.match(css,/translate:-50% -50%/);
});

test('precision betting stays isolated from protected economy contracts',()=>{
  assert.doesNotMatch(js,/marino_coin|casino_chips|tap_coin|marino_secure_rpc|\brpc\s*\(/);assert.match(js,/MarinoEconomyBridge/);assert.doesNotMatch(js,/MarinoDemoWallet\.(debit|credit)/);
});
