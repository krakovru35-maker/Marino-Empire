import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const html=fs.readFileSync('public/index.html','utf8');
const js=fs.readFileSync('public/js/phase-2b.js','utf8');
const css=fs.readFileSync('public/styles/phase-2b.css','utf8');

test('casino building catalogue contains ten original server-mapped cards',()=>{for(const name of ['Slot Salonu','Rulet Masası','Blackjack Lounge','VIP Salon','Casino Bar','Güvenlik Merkezi','Otel Katı','Marina','Özel Kasa','Marino Penthouse'])assert.match(js,new RegExp(name));assert.match(js,/server\?\.next_cost_coin/);assert.match(js,/server\?\.current_income_per_hour/);});
test('real building upgrades keep the existing authoritative action',()=>{assert.match(html,/return doAction\('upgrade_building', \{ p_building_key: buildingKey \}\)/);assert.match(html,/if \(!isLocalPreview\)/);assert.doesNotMatch(js,/\brpc\s*\(|marino_secure_rpc|tap_coin|processState/);});
test('task system has four categories and eleven progression signals',()=>{for(const label of ['Günlük','Haftalık','İlerleme','Sosyal'])assert.match(js,new RegExp(label));for(const metric of ['taps','energy','collects','upgrades','owned','level','combo','cipher','casino','friends','streak'])assert.match(js,new RegExp(`'${metric}'`));});
test('reward points are memory-only and unavailable to real-mode claims',()=>{assert.match(js,/if \(!preview\(\)\) return;/);assert.match(js,/state\.rewardPoints \+= task\.points/);assert.doesNotMatch(js,/localStorage|sessionStorage|indexedDB/);});
test('daily retention explains server authority and no fake urgency',()=>{assert.match(js,/Kalıcı ödüller yalnız sunucu onayıyla verilir/);assert.doesNotMatch(js,/son şans|kaçırma|garanti kazanç|hemen yatır/i);});
test('responsive core loop covers compact mobile viewports',()=>{assert.match(css,/@media\(max-height:700px\)/);assert.match(css,/@media\(max-height:600px\)/);assert.match(css,/grid-template-columns:repeat\(2,minmax\(0,1fr\)\)/);});
test('protected contracts and static IDs remain intact',()=>{assert.match(html,/function authenticateTelegram\(/);assert.match(html,/db\.rpc\('marino_secure_rpc'/);assert.match(html,/rpc\('tap_coin', \{ p_taps: 1 \}\)/);assert.match(html,/function processState\(d\)/);const markup=html.replace(/<script(?:\s[^>]*)?>[\s\S]*?<\/script>/gi,'');const ids=[...markup.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length);});
