import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = file => fs.readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const html = read('public/index.html');
const css = read('public/styles/phase-1b.css');
const migration = read('supabase/migrations/202607180005_server_mining_bonus_tasks.sql');

test('home is reduced to one command-sheet entry while all shortcuts remain reachable', () => {
  assert.doesNotMatch(html, /class="quick-bar home-quick-actions"/);
  assert.match(html, /id="btnEmpireHub"/);
  assert.match(html, /class="command-menu-grid"/);
  for (const id of ['btnOpenBoost','btnOpenAirdrop','btnOpenClaimMining']) {
    assert.equal([...html.matchAll(new RegExp(`id="${id}"`, 'g'))].length, 1);
  }
  for (const tab of ['buildings','tasks','store']) assert.match(html, new RegExp(`data-command-tab="${tab}"`));
  assert.match(css, /\.command-menu-grid\{display:grid/);
});

test('mining and casino bonus missions are catalogued with server progress rules', () => {
  for (const task of ['claim_profile_link','claim_mine_daily','claim_mine_weekly','claim_request_first','bonus_slot_route','bonus_roulette_route','bonus_blackjack_route']) {
    assert.match(migration, new RegExp(`'${task}'`));
  }
  for (const metric of ['claim_profile_bound','claim_coin_mined','claim_request_created','slot_spin','roulette_spin','blackjack_hand']) {
    assert.match(migration, new RegExp(`'${metric}'`));
  }
});

test('claim progress comes only from private triggers on server-owned tables', () => {
  assert.match(migration, /after insert on public\.marino_site_accounts/i);
  assert.match(migration, /after update of lifetime_mined on public\.marino_claim_coin_wallets/i);
  assert.match(migration, /after insert on public\.marino_reward_claim_requests/i);
  assert.match(migration, /perform public\.marino_record_task_progress/i);
  assert.match(migration, /revoke all on function public\.marino_progress_claim_coin_mined\(\) from public,anon,authenticated/i);
  assert.doesNotMatch(html, /marino_record_task_progress/);
});

test('task state exposes authoritative progress and the UI blocks premature claims', () => {
  assert.match(migration, /coalesce\(r\.goal,0\) goal,coalesce\(p\.progress_value,0\) progress/i);
  assert.match(html, /progressBlocked=goal>0&&progress<goal/);
  assert.match(html, /Sunucu ilerlemesi:/);
  assert.match(html, /server-task-progress/);
  assert.match(css, /\.server-task-progress/);
});

test('daily and weekly claims reset only at their server period boundary', () => {
  assert.match(migration, /v_task\.task_type in \('daily','weekly'\)/i);
  assert.match(migration, /date_trunc\('week',current_date\)::date/i);
  assert.match(migration, /marino_task_period_key\(v_task\.task_type\)/i);
  assert.match(migration, /revoke all on function public\.marino_claim_task\(text,text,integer,text\) from public,anon,authenticated/i);
});
