-- ════════════════════════════════════════════════════════════════
-- MARINO EMPIRE — Hamster Kombat Tier Supabase Migration
-- Run this ONCE in Supabase Dashboard → SQL Editor → Run
-- Creates 4 new tables + 13 new RPC functions for:
--   • Daily Combo  (3-of-12 cards puzzle, +5,000,000 coin/day)
--   • Daily Cipher (Morse keyboard puzzle,  +1,000,000 coin/day)
--   • Boost Center (Full Energy, Tap Boost, Multitap, Energy Limit, Auto-tap)
--   • Wallet / Airdrop (TON wallet link + listing checklist)
-- Safe to re-run (uses CREATE OR REPLACE / IF NOT EXISTS).
-- ════════════════════════════════════════════════════════════════

-- ─── 1) Tables ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marino_daily_combo (
  id BIGSERIAL PRIMARY KEY,
  telegram_id TEXT NOT NULL,
  combo_date DATE NOT NULL,
  attempts_left INT NOT NULL DEFAULT 6,
  picks JSONB DEFAULT '[]'::jsonb,
  won BOOLEAN DEFAULT false,
  reward_claimed BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(telegram_id, combo_date)
);
CREATE INDEX IF NOT EXISTS idx_marino_combo_player ON marino_daily_combo(telegram_id, combo_date DESC);

CREATE TABLE IF NOT EXISTS marino_daily_cipher (
  id BIGSERIAL PRIMARY KEY,
  telegram_id TEXT NOT NULL,
  cipher_date DATE NOT NULL,
  attempts INT NOT NULL DEFAULT 0,
  won BOOLEAN DEFAULT false,
  reward_claimed BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(telegram_id, cipher_date)
);
CREATE INDEX IF NOT EXISTS idx_marino_cipher_player ON marino_daily_cipher(telegram_id, cipher_date DESC);

CREATE TABLE IF NOT EXISTS marino_player_boosts (
  telegram_id TEXT PRIMARY KEY,
  multitap_lvl INT NOT NULL DEFAULT 0,
  energy_lvl INT NOT NULL DEFAULT 0,
  auto_tap_until TIMESTAMPTZ,
  full_energy_date DATE,
  full_energy_used INT NOT NULL DEFAULT 0,
  tap_boost_date DATE,
  tap_boost_used INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marino_wallets (
  telegram_id TEXT PRIMARY KEY,
  ton_address TEXT,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  airdrop_eligible BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 2) Deterministic daily puzzles ──────────────────────────────
CREATE OR REPLACE FUNCTION marino_get_today_combo() RETURNS text[]
LANGUAGE plpgsql STABLE AS $$
DECLARE
  deck text[] := ARRAY['spade_a','heart_a','club_a','diamond_a','king','queen','jack','joker','chip','dice','wheel','slot']::text[];
  d text := to_char(CURRENT_DATE, 'YYYY-MM-DD');
  seed bigint;
  i int; j int; tmp text;
BEGIN
  seed := abs(hashtext('combo_' || d));
  FOR i IN REVERSE 12..2 LOOP
    seed := (seed * 9301 + 49297) % 233280;
    j := 1 + ((seed::numeric * i / 233280)::int);
    IF j > i THEN j := i; END IF;
    IF j < 1 THEN j := 1; END IF;
    tmp := deck[i]; deck[i] := deck[j]; deck[j] := tmp;
  END LOOP;
  RETURN ARRAY(SELECT x FROM unnest(deck[1:3]) x ORDER BY x);
END$$;

CREATE OR REPLACE FUNCTION marino_get_today_cipher() RETURNS text
LANGUAGE plpgsql STABLE AS $$
DECLARE
  words text[] := ARRAY['MARINO','CASINO','JACKPOT','EMPIRE','ROULETTE','POKER','VEGAS','CHIPS','WINNER','FORTUNE','BANKROLL','BLACKJACK'];
  d text := to_char(CURRENT_DATE, 'YYYY-MM-DD');
  seed bigint;
BEGIN
  seed := abs(hashtext('cipher_' || d));
  RETURN words[1 + (seed % array_length(words,1))];
END$$;

-- ─── 3) Claim RPCs ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION marino_claim_combo(p_telegram_id text, p_picks text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row marino_daily_combo;
  v_correct text[];
  v_picks_sorted text[];
  v_reward bigint := 5000000;
BEGIN
  IF array_length(p_picks,1) <> 3 THEN
    RETURN jsonb_build_object('ok',false,'error','3 cards required');
  END IF;
  v_picks_sorted := ARRAY(SELECT DISTINCT unnest(p_picks) ORDER BY 1);
  v_correct := marino_get_today_combo();

  INSERT INTO marino_daily_combo(telegram_id, combo_date)
  VALUES (p_telegram_id, CURRENT_DATE)
  ON CONFLICT (telegram_id, combo_date) DO NOTHING;

  SELECT * INTO v_row FROM marino_daily_combo
   WHERE telegram_id = p_telegram_id AND combo_date = CURRENT_DATE FOR UPDATE;

  IF v_row.won THEN
    RETURN jsonb_build_object('ok',false,'error','already_won','attempts_left',v_row.attempts_left);
  END IF;
  IF v_row.attempts_left <= 0 THEN
    RETURN jsonb_build_object('ok',false,'error','no_attempts','attempts_left',0);
  END IF;

  IF v_picks_sorted = v_correct THEN
    UPDATE marino_daily_combo
      SET won=true, picks=to_jsonb(p_picks), attempts_left=attempts_left-1,
          reward_claimed=v_reward, updated_at=NOW()
      WHERE id=v_row.id;
    UPDATE marino_players SET marino_coin = marino_coin + v_reward, updated_at=NOW()
      WHERE telegram_id = p_telegram_id;
    RETURN jsonb_build_object('ok',true,'won',true,'reward',v_reward,'attempts_left',v_row.attempts_left-1);
  ELSE
    UPDATE marino_daily_combo
      SET picks=to_jsonb(p_picks), attempts_left=attempts_left-1, updated_at=NOW()
      WHERE id=v_row.id;
    RETURN jsonb_build_object('ok',true,'won',false,'reward',0,'attempts_left',v_row.attempts_left-1);
  END IF;
END$$;

CREATE OR REPLACE FUNCTION marino_claim_cipher(p_telegram_id text, p_word text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row marino_daily_cipher;
  v_answer text;
  v_reward bigint := 1000000;
BEGIN
  v_answer := marino_get_today_cipher();
  INSERT INTO marino_daily_cipher(telegram_id, cipher_date)
  VALUES (p_telegram_id, CURRENT_DATE)
  ON CONFLICT (telegram_id, cipher_date) DO NOTHING;
  SELECT * INTO v_row FROM marino_daily_cipher
   WHERE telegram_id = p_telegram_id AND cipher_date = CURRENT_DATE FOR UPDATE;
  IF v_row.won THEN
    RETURN jsonb_build_object('ok',false,'error','already_won');
  END IF;
  IF upper(trim(p_word)) = v_answer THEN
    UPDATE marino_daily_cipher SET won=true, attempts=attempts+1, reward_claimed=v_reward, updated_at=NOW() WHERE id=v_row.id;
    UPDATE marino_players SET marino_coin = marino_coin + v_reward, updated_at=NOW()
      WHERE telegram_id = p_telegram_id;
    RETURN jsonb_build_object('ok',true,'won',true,'reward',v_reward);
  ELSE
    UPDATE marino_daily_cipher SET attempts=attempts+1, updated_at=NOW() WHERE id=v_row.id;
    RETURN jsonb_build_object('ok',true,'won',false,'reward',0,'attempts',v_row.attempts+1);
  END IF;
END$$;

-- ─── 4) Boost RPCs ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _marino_ensure_boost(p_telegram_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO marino_player_boosts(telegram_id) VALUES (p_telegram_id)
  ON CONFLICT (telegram_id) DO NOTHING;
  UPDATE marino_player_boosts
    SET full_energy_used = CASE WHEN full_energy_date = CURRENT_DATE THEN full_energy_used ELSE 0 END,
        full_energy_date = CURRENT_DATE,
        tap_boost_used = CASE WHEN tap_boost_date = CURRENT_DATE THEN tap_boost_used ELSE 0 END,
        tap_boost_date = CURRENT_DATE
    WHERE telegram_id = p_telegram_id;
END$$;

CREATE OR REPLACE FUNCTION marino_get_boosts(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r marino_player_boosts;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object(
    'multitap_lvl', r.multitap_lvl,
    'energy_lvl', r.energy_lvl,
    'full_energy_left', 3 - r.full_energy_used,
    'tap_boost_left', 3 - r.tap_boost_used,
    'auto_tap_until', r.auto_tap_until,
    'auto_tap_active', (r.auto_tap_until IS NOT NULL AND r.auto_tap_until > NOW())
  );
END$$;

CREATE OR REPLACE FUNCTION marino_use_full_energy(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r marino_player_boosts; p marino_players;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF r.full_energy_used >= 3 THEN RETURN jsonb_build_object('ok',false,'error','no_uses_left'); END IF;
  UPDATE marino_player_boosts SET full_energy_used = full_energy_used+1, updated_at=NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_players SET energy = max_energy, last_energy_update = NOW(), updated_at = NOW()
    WHERE telegram_id = p_telegram_id RETURNING * INTO p;
  RETURN jsonb_build_object('ok',true,'energy',p.energy,'max_energy',p.max_energy,'left',2-r.full_energy_used);
END$$;

CREATE OR REPLACE FUNCTION marino_use_tap_boost(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r marino_player_boosts;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF r.tap_boost_used >= 3 THEN RETURN jsonb_build_object('ok',false,'error','no_uses_left'); END IF;
  UPDATE marino_player_boosts SET tap_boost_used = tap_boost_used+1, updated_at=NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'multiplier',5,'duration_sec',20,'left',2-r.tap_boost_used);
END$$;

CREATE OR REPLACE FUNCTION marino_upgrade_multitap(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r marino_player_boosts; p marino_players; cost bigint;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  cost := 1000 * (2 ^ r.multitap_lvl)::bigint;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, tap_power = tap_power + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET multitap_lvl = multitap_lvl + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'new_level',r.multitap_lvl+1,'new_tap_power',p.tap_power+1,'cost',cost);
END$$;

CREATE OR REPLACE FUNCTION marino_upgrade_energy_limit(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r marino_player_boosts; p marino_players; cost bigint;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  cost := 1000 * (2 ^ r.energy_lvl)::bigint;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, max_energy = max_energy + 500, energy = max_energy + 500, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET energy_lvl = energy_lvl + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'new_level',r.energy_lvl+1,'new_max_energy',p.max_energy+500,'cost',cost);
END$$;

CREATE OR REPLACE FUNCTION marino_activate_auto_tap(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE p marino_players; cost bigint := 5000;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET auto_tap_until = NOW() + INTERVAL '12 hours', updated_at = NOW()
    WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'until', (NOW() + INTERVAL '12 hours'),'cost',cost);
END$$;

-- ─── 5) Wallet / Airdrop ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION marino_connect_wallet(p_telegram_id text, p_ton_address text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO marino_wallets(telegram_id, ton_address)
  VALUES (p_telegram_id, COALESCE(p_ton_address, 'UQ' || substr(md5(p_telegram_id || NOW()::text), 1, 46)))
  ON CONFLICT (telegram_id) DO UPDATE SET ton_address = COALESCE(EXCLUDED.ton_address, marino_wallets.ton_address), updated_at = NOW();
  RETURN jsonb_build_object('ok',true,'ton_address',(SELECT ton_address FROM marino_wallets WHERE telegram_id=p_telegram_id));
END$$;

CREATE OR REPLACE FUNCTION marino_airdrop_status(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE p marino_players; w marino_wallets;
BEGIN
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id;
  SELECT * INTO w FROM marino_wallets WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object(
    'wallet_connected', w.ton_address IS NOT NULL,
    'ton_address', w.ton_address,
    'casino_level', COALESCE(p.casino_level, 0),
    'casino_chips', COALESCE(p.casino_chips, 0),
    'reputation', COALESCE(p.reputation, 0),
    'referrals', (SELECT COUNT(*) FROM marino_players WHERE referred_by = p_telegram_id),
    'tasks_completed', COALESCE(jsonb_array_length(to_jsonb(p.completed_tasks)), 0)
  );
END$$;

-- ─── 6) Bundle: all HK state in one round-trip ──────────────────
CREATE OR REPLACE FUNCTION marino_hk_state(p_telegram_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE combo marino_daily_combo; cipher marino_daily_cipher;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO combo FROM marino_daily_combo WHERE telegram_id = p_telegram_id AND combo_date = CURRENT_DATE;
  SELECT * INTO cipher FROM marino_daily_cipher WHERE telegram_id = p_telegram_id AND cipher_date = CURRENT_DATE;
  RETURN jsonb_build_object(
    'combo', jsonb_build_object(
      'attempts_left', COALESCE(combo.attempts_left, 6),
      'won', COALESCE(combo.won, false),
      'reward', COALESCE(combo.reward_claimed, 0)
    ),
    'cipher', jsonb_build_object(
      'won', COALESCE(cipher.won, false),
      'attempts', COALESCE(cipher.attempts, 0),
      'reward', COALESCE(cipher.reward_claimed, 0)
    ),
    'boosts', marino_get_boosts(p_telegram_id),
    'airdrop', marino_airdrop_status(p_telegram_id)
  );
END$$;

-- ─── 7) Grants ───────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION marino_claim_combo(text,text[]) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_claim_cipher(text,text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_use_full_energy(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_use_tap_boost(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_upgrade_multitap(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_upgrade_energy_limit(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_activate_auto_tap(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_get_boosts(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_connect_wallet(text,text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_airdrop_status(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_hk_state(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_get_today_combo() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION marino_get_today_cipher() TO anon, authenticated;

-- ✅ DONE — Now refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
